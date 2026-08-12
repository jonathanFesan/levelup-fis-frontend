import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/curriculo_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/capitulo_progress_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/pdf_viewer.dart';

/// Tela de Curiosidade — Capítulo tipo 'curiosidade' de um Bloco (ver
/// backend/sql/011_capitulos_livres.sql). Conteúdo flexível: texto, PDF,
/// imagem e vídeo, qualquer combinação, todos opcionais.
///
/// FASE 2 DO CURRÍCULO DINÂMICO: Curiosidade faz parte da SEQUÊNCIA
/// PRINCIPAL da trilha (não é mais um extra solto) — pra liberar o
/// próximo passo, o aluno precisa tocar em "Continuar", que marca este
/// Capítulo como concluído (ver sql/012_capitulo_progress.sql), a mesma
/// mecânica do "ENTENDIDO" do Resumo, só que sem recompensa em Joules
/// (é conteúdo extra, não ganha XP). Vídeo abre externo (mesmo
/// mecanismo já usado em videos_screen.dart via url_launcher) — sem
/// player embutido.
class CuriosidadeScreen extends ConsumerStatefulWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;
  final CapituloModel capitulo;

  const CuriosidadeScreen({
    super.key,
    required this.modulo,
    required this.topico,
    required this.capitulo,
  });

  @override
  ConsumerState<CuriosidadeScreen> createState() => _CuriosidadeScreenState();
}

class _CuriosidadeScreenState extends ConsumerState<CuriosidadeScreen> {
  bool _enviando = false;
  String? _erro;

  Future<void> _abrirVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
        );
      }
    }
  }

  Future<void> _continuar() async {
    final accessToken = ref.read(authProvider).accessToken;
    if (accessToken == null) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      await GameRepository().concluirCapitulo(
        accessToken,
        capituloId: widget.capitulo.id,
      );
      ref.invalidate(capituloProgressProvider(widget.topico.id));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _erro = 'Não foi possível continuar agora. Tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = widget.capitulo.conteudo;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: Text(
          '${widget.modulo.titulo} · ${widget.topico.titulo} · ${widget.capitulo.titulo}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.capitulo.titulo,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: (conteudo == null || conteudo.vazio)
                    ? const Center(
                        child: Text(
                          'O conteúdo desta Curiosidade ainda não foi '
                          'cadastrado no painel administrativo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView(
                        children: [
                          if (conteudo.texto != null &&
                              conteudo.texto!.trim().isNotEmpty) ...[
                            Text(
                              conteudo.texto!,
                              style: const TextStyle(
                                color: AppColors.textoQuaseBranco,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (conteudo.imagemUrl != null &&
                              conteudo.imagemUrl!.trim().isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                conteudo.imagemUrl!.trim(),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: const Text(
                                    'Não foi possível carregar a imagem.',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (conteudo.videoUrl != null &&
                              conteudo.videoUrl!.trim().isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _abrirVideo(conteudo.videoUrl!.trim()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: const BorderSide(color: AppColors.gold),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.play_circle_outline_rounded),
                                label: const Text(
                                  'Assistir vídeo',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (conteudo.pdfUrl != null &&
                              conteudo.pdfUrl!.trim().isNotEmpty)
                            SizedBox(
                              height: 420,
                              child: Container(
                                width: double.infinity,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: PdfViewer(url: conteudo.pdfUrl!.trim()),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_erro!, style: const TextStyle(color: AppColors.error)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _enviando ? null : _continuar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bg,
                          ),
                        )
                      : const Text(
                          'CONTINUAR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/game_repository.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/topic_content_provider.dart';
import '../../domain/providers/topic_progress_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';

/// Canal nativo mínimo (implementado direto em MainActivity.kt, sem
/// pacote de terceiro) pra ligar/desligar FLAG_SECURE no Android
/// enquanto a tela de Resumo em PDF está aberta.
const _screenSecurityChannel = MethodChannel('levelup_fis/screen_security');

/// Tela de Resumo — primeiro nó de cada tópico. Ler + clicar
/// "Entendido" concede +10 J (uma vez só, idempotente no backend — ver
/// app/routes/topic_progress.py) e libera o nó de Fixação.
///
/// ATUALIZADO NESTA SESSÃO: o texto do resumo deixou de ser um
/// placeholder fixo — agora vem de topicContentProvider, que busca
/// GET /topic-content/{topico}. Esse conteúdo é escrito pelo painel
/// administrativo (aba "Resumo" em painel-perguntas.html), direto na
/// tabela topic_content — sem precisar de deploy nenhum pra atualizar
/// o texto de um tópico. Se o admin ainda não salvou nada pra esse
/// tópico, mostramos um aviso (não um erro) — ver _buildConteudo.
///
/// ATUALIZADO DE NOVO NESTA SESSÃO: o Resumo agora pode ser um PDF em
/// vez de texto — se o admin colar um link no painel
/// (topic_content.resumo_pdf_url, ver sql/009_resumo_pdf.sql), esta
/// tela baixa o PDF pra um arquivo temporário e mostra num visualizador
/// nativo com zoom (flutter_pdfview), em vez do texto. Enquanto essa
/// tela estiver aberta, ativamos FLAG_SECURE no Android (a tela fica
/// preta em qualquer captura/gravação) — no iOS o sistema não permite
/// bloquear isso de verdade, então lá não tem efeito (decisão
/// confirmada: aceitável, já que não há alternativa no iOS).
class ResumoScreen extends ConsumerStatefulWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const ResumoScreen({super.key, required this.modulo, required this.topico});

  @override
  ConsumerState<ResumoScreen> createState() => _ResumoScreenState();
}

class _ResumoScreenState extends ConsumerState<ResumoScreen> {
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _ativarProtecaoContraCaptura();
  }

  @override
  void dispose() {
    _desativarProtecaoContraCaptura();
    super.dispose();
  }

  /// Liga o FLAG_SECURE nativo do Android (ver MainActivity.kt) —
  /// bloqueia screenshot e gravação de tela de verdade enquanto esta
  /// tela estiver na frente. Sem efeito no iOS (o canal só existe do
  /// lado Android; envolto em try/catch pra nunca travar a tela de
  /// Resumo caso a chamada nativa falhe por qualquer motivo).
  Future<void> _ativarProtecaoContraCaptura() async {
    if (!Platform.isAndroid) return;
    try {
      await _screenSecurityChannel.invokeMethod('enableSecure');
    } catch (_) {
      // Falha silenciosa — pior caso, a tela some sem proteção extra,
      // mas continua funcionando normalmente.
    }
  }

  Future<void> _desativarProtecaoContraCaptura() async {
    if (!Platform.isAndroid) return;
    try {
      await _screenSecurityChannel.invokeMethod('disableSecure');
    } catch (_) {}
  }

  Future<void> _marcarEntendido() async {
    final accessToken = ref.read(authProvider).accessToken;
    if (accessToken == null) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final resultado = await GameRepository().marcarResumoConcluido(
        accessToken,
        topico: widget.topico.id,
      );

      final joulesGanho = resultado['joules_ganhos'] as int? ?? 0;
      final joulesTotais = resultado['joules_totais'] as int?;

      // Reflete o total atualizado (se o backend devolveu) sem tocar em
      // fótons/nível — mesmo princípio de atualizarTotais() em
      // exercise_screen.dart: nunca soma localmente.
      final user = ref.read(userProvider).user;
      if (joulesTotais != null && user != null) {
        ref.read(userProvider.notifier).atualizarTotais(
              joules: joulesTotais,
              fotons: user.fotons,
              nivel: user.nivel,
            );
      }

      ref.invalidate(topicProgressProvider(widget.topico.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            joulesGanho > 0
                ? 'Resumo concluído! +$joulesGanho J'
                : 'Resumo já estava concluído.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _erro = 'Não foi possível concluir agora. Tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Corpo do card de conteúdo — trata os 3 estados possíveis do que
  /// vem do backend: carregando, erro de rede, e sucesso. No sucesso,
  /// se o admin colou um link de PDF no painel, mostra o PDF; senão,
  /// cai no texto (ou no aviso de "ainda não cadastrado").
  Widget _buildConteudo(AsyncValue<TopicContentState> conteudoAsync) {
    return conteudoAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Não foi possível carregar o conteúdo do resumo agora.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(topicContentProvider(widget.topico.id)),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
      data: (conteudo) {
        final temPdf = conteudo.resumoPdfUrl != null &&
            conteudo.resumoPdfUrl!.trim().isNotEmpty;
        if (temPdf) {
          return _PdfViewer(url: conteudo.resumoPdfUrl!.trim());
        }
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              (conteudo.resumoTexto == null ||
                      conteudo.resumoTexto!.trim().isEmpty)
                  ? 'O conteúdo do resumo deste tópico ainda não foi cadastrado '
                      'no painel administrativo.'
                  : conteudo.resumoTexto!,
              style: TextStyle(
                color: (conteudo.resumoTexto == null ||
                        conteudo.resumoTexto!.trim().isEmpty)
                    ? AppColors.muted
                    : AppColors.textoQuaseBranco,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressoAsync = ref.watch(topicProgressProvider(widget.topico.id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: Text(
          '${widget.modulo.titulo} · ${widget.topico.titulo} · Resumo',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ),
      body: SafeArea(
        child: progressoAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Erro ao carregar o progresso deste tópico.',
                    style: TextStyle(color: AppColors.cream),
                  ),
                  const SizedBox(height: 8),
                  // DIAGNÓSTICO TEMPORÁRIO — mesmo padrão já usado em
                  // game_repository.dart (getProfile/getVideos): mostra
                  // o erro real pra achar a causa raiz mais rápido.
                  // Remover depois de identificado.
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(topicProgressProvider(widget.topico.id)),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
          data: (progresso) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.topico.titulo,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: _buildConteudo(
                      ref.watch(topicContentProvider(widget.topico.id)),
                    ),
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
                    onPressed: _enviando ? null : _marcarEntendido,
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
                        : Text(
                            progresso.resumoConcluido ? 'CONTINUAR' : 'ENTENDIDO',
                            style: const TextStyle(
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
      ),
    );
  }
}

/// Baixa o PDF de [url] pra um arquivo temporário e mostra com
/// flutter_pdfview (zoom por pinça nativo da plataforma, sem nenhum
/// botão de compartilhar/imprimir nosso). Cada instância baixa uma vez
/// só (cache em memória via _futuroArquivo, criado em initState) — abrir
/// e fechar a tela de novo baixa de novo, o que é aceitável pro
/// tamanho normal de um PDF de resumo.
class _PdfViewer extends StatefulWidget {
  final String url;

  const _PdfViewer({required this.url});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late Future<String> _futuroArquivo;

  @override
  void initState() {
    super.initState();
    _futuroArquivo = _baixarPdf(widget.url);
  }

  @override
  void didUpdateWidget(covariant _PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _futuroArquivo = _baixarPdf(widget.url);
    }
  }

  Future<String> _baixarPdf(String url) async {
    final resposta = await http.get(Uri.parse(url));
    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível baixar o PDF (status ${resposta.statusCode}). '
        'Confira se o link está com o compartilhamento público ativado.',
      );
    }
    final pastaTemp = await getTemporaryDirectory();
    // Nome de arquivo baseado no hash da URL, pra não colidir entre
    // tópicos diferentes abertos na mesma sessão do app.
    final arquivo = File(
      '${pastaTemp.path}/resumo_${url.hashCode}.pdf',
    );
    await arquivo.writeAsBytes(resposta.bodyBytes, flush: true);
    return arquivo.path;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _futuroArquivo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _futuroArquivo = _baixarPdf(widget.url);
                  }),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        return PDFView(
          filePath: snapshot.data!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: false,
          fitPolicy: FitPolicy.WIDTH,
          backgroundColor: AppColors.card,
        );
      },
    );
  }
}

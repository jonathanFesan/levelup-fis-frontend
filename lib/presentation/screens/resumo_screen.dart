import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/game_repository.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/topic_content_provider.dart';
import '../../domain/providers/topic_progress_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';

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

  /// Corpo do card de conteúdo — trata os 3 estados possíveis do texto
  /// vindo do backend: carregando, erro de rede, e sucesso (com ou sem
  /// texto ainda salvo pelo admin no painel).
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
      data: (conteudo) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          (conteudo.resumoTexto == null || conteudo.resumoTexto!.trim().isEmpty)
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
          '${widget.modulo.titulo} · Resumo',
          style: const TextStyle(color: AppColors.cream, fontSize: 15),
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
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
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

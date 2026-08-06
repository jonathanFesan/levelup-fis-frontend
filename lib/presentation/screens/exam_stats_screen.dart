import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exam_attempt_model.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/exam_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/exam_mode_sheet.dart';
import 'exam_screen.dart';

/// Estatísticas da Prova de um tópico — histórico de tentativas
/// (acertos, erros, tempo total, tempo médio por questão) + botão pra
/// tentar de novo. Aberta a partir do nó "Prova" no mapa quando já
/// existe pelo menos uma tentativa concluída (ver map_screen.dart).
class ExamStatsScreen extends ConsumerWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const ExamStatsScreen({super.key, required this.modulo, required this.topico});

  Future<void> _tentarNovamente(BuildContext context, WidgetRef ref) async {
    final modo = await showExamModeSheet(context);
    if (modo == null || !context.mounted) return;

    ref.read(examProvider.notifier).limpar();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamScreen(modulo: modulo, topico: topico, modo: modo),
      ),
    );
    // Ao voltar da prova (finalizada ou não), atualiza a lista.
    ref.invalidate(examAttemptsProvider(topico.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tentativasAsync = ref.watch(examAttemptsProvider(topico.id));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.cream,
        elevation: 0,
        title: Text('${topico.titulo} · Prova'),
      ),
      body: tentativasAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Erro ao carregar estatísticas.',
                  style: TextStyle(color: AppColors.cream),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(examAttemptsProvider(topico.id)),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (tentativas) {
          final finalizadas = tentativas.where((t) => t.finalizada).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _tentarNovamente(context, ref),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Tentar novamente'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Histórico (${finalizadas.length} '
                '${finalizadas.length == 1 ? 'tentativa' : 'tentativas'})',
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              if (finalizadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhuma tentativa concluída ainda.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                for (final t in finalizadas) _TentativaCard(tentativa: t),
            ],
          );
        },
      ),
    );
  }
}

class _TentativaCard extends StatelessWidget {
  final ExamAttemptSummary tentativa;

  const _TentativaCard({required this.tentativa});

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _formatarSegundos(int segundos) {
    final m = segundos ~/ 60;
    final s = segundos % 60;
    return '${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final acertos = tentativa.acertos ?? 0;
    final erros = tentativa.erros ?? 0;
    final tempoTotal = tentativa.tempoTotalSegundos ?? 0;
    final tempoMedio = tentativa.tempoMedioPorQuestaoSegundos;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tentativa.modo == 'dificil'
                    ? Icons.local_fire_department_rounded
                    : Icons.sentiment_satisfied_alt_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                tentativa.modo == 'dificil' ? 'Modo difícil' : 'Modo fácil',
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                _formatarData(tentativa.iniciadoEm),
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                label: 'Acertos',
                valor: '$acertos',
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.cancel_rounded,
                color: AppColors.error,
                label: 'Erros',
                valor: '$erros',
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.timer_rounded,
                color: AppColors.muted,
                label: 'Tempo total',
                valor: _formatarSegundos(tempoTotal),
              ),
            ],
          ),
          if (tempoMedio != null) ...[
            const SizedBox(height: 8),
            Text(
              '≈ ${_formatarSegundos(tempoMedio.round())} por questão',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String valor;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              valor,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
      ],
    );
  }
}

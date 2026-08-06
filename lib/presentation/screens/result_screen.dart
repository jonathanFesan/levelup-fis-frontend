import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/progress_model.dart';
import '../theme/app_colors.dart';

/// Tela de Resultado — LevelUp Fís
///
/// Recebe o [AnswerResultModel] (via construtor, empilhada sobre a tela
/// de Exercício com `Navigator.push` — ver exercise_screen.dart). Mostra
/// feedback de acerto/erro, a resposta correta (quando errou), a
/// explicação da questão e os Joules/Fótons ganhos (nomenclatura
/// temática — mesmo dado de xp/moedas por baixo, ver user_model.dart).
///
/// Redesenhada nesta sessão para seguir os mesmos moldes visuais já
/// estabelecidos em exercise_screen.dart: fundo navy (AppColors.bg),
/// texto principal em `textoQuaseBranco`, fonte de leitura Lora, botão
/// largo dourado e espaço reservado para a logo no rodapé.
///
/// Navegação ao continuar: fecha esta tela E a tela de Exercício de uma
/// vez (dois `Navigator.pop()`), voltando direto para a trilha de
/// exercícios do tópico (TopicExercisesScreen) — que continua embaixo na
/// pilha, com o progresso já atualizado por `completeNode()`. IMPORTANTE:
/// não usar `context.go('/map')` aqui — como Exercício/Resultado agora
/// são empilhados com Navigator.push (não são mais rotas do GoRouter na
/// prática), `context.go` não tem efeito nenhum sobre essas telas
/// empilhadas por cima.
class ResultScreen extends StatelessWidget {
  final AnswerResultModel resultado;

  const ResultScreen({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    final acertou = resultado.acertou;
    final corDestaque = acertou ? AppColors.success : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(),

              // ---- Selo de acerto/erro ----
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: corDestaque, width: 3),
                ),
                child: Icon(
                  acertou ? Icons.check_rounded : Icons.close_rounded,
                  size: 52,
                  color: corDestaque,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                acertou ? 'Mandou bem!' : 'Quase lá!',
                style: GoogleFonts.lora(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: corDestaque,
                ),
              ),

              const SizedBox(height: 24),

              // ---- Resposta correta (só quando errou) ----
              if (!acertou) ...[
                const Text(
                  'RESPOSTA CORRETA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    resultado.respostaCorreta,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textoQuaseBranco,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ---- Recompensas (só quando acertou) ----
              // Fótons deixaram de ser dados em toda resposta certa
              // (ver documento de Economia) — só aparecem aqui quando
              // moedasGanhas > 0 (hoje, só ao vencer um "Boss").
              if (acertou)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RewardChip(
                      icon: Icons.bolt_rounded,
                      label: '+${resultado.xpGanho} J',
                    ),
                    if (resultado.moedasGanhas > 0) ...[
                      const SizedBox(width: 12),
                      _RewardChip(
                        icon: Icons.auto_awesome_rounded,
                        label: '+${resultado.moedasGanhas}',
                      ),
                    ],
                  ],
                ),

              // ---- Capítulo desbloqueado (bônus único de conclusão da
              // Fixação — ver questions.py/answer_question) ----
              if (resultado.capituloDesbloqueado) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_open_rounded, color: AppColors.bg, size: 26),
                      const SizedBox(height: 6),
                      const Text(
                        'CAPÍTULO CONCLUÍDO!',
                        style: TextStyle(
                          color: AppColors.bg,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bônus de +${resultado.bonusCapituloGanho} J · Próximo '
                        'capítulo e Treino/Prova liberados!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.bg,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ---- Explicação ----
              if (resultado.explicacao != null &&
                  resultado.explicacao!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'EXPLICAÇÃO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        resultado.explicacao!,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.lora(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.textoQuaseBranco,
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // ---- Botão largo "Próxima questão" ----
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Fecha o Resultado e o Exercício de uma vez, voltando
                    // direto pra trilha de exercícios do tópico (que
                    // continua embaixo na pilha de navegação).
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CONTINUAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Espaço reservado para a logo do app (mesmo padrão da
              // tela de Exercício). Trocar por
              // Image.asset('assets/logo/logo_mark.png', height: 28)
              // quando o asset final da marca for adicionado ao pubspec.
              const SizedBox(height: 28),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RewardChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textoQuaseBranco,
            ),
          ),
        ],
      ),
    );
  }
}
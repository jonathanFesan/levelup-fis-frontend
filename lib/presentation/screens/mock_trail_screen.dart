import 'package:flutter/material.dart';

import '../../domain/models/curriculum.dart';
import '../theme/app_colors.dart';
import '../widgets/exercise_trail.dart';

/// Trilha de TESTE — mostra a mesma UI do Mapa real (curva, cometa, glow),
/// mas alimentada com nós falsos gerados localmente, sem nenhuma chamada
/// de API nem pergunta de verdade por trás.
///
/// Usada só para os tópicos de Mecânica que ainda não têm conteúdo no
/// backend (ver `TopicoInfo.mockExercicios` em curriculum.dart), pra dar
/// pra testar o fluxo de navegação completo (Módulo → Tópico →
/// Exercícios) antes do conteúdo real existir.
///
/// Comportamento do dado falso: o primeiro nó vem desbloqueado e "atual"
/// (pulsando, igual aconteceria com um aluno começando o tópico agora);
/// os demais vêm bloqueados. Nenhum nó toca em nada real ao ser tocado —
/// só mostra um aviso de que é uma pré-visualização.
class MockTrailScreen extends StatelessWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const MockTrailScreen({
    super.key,
    required this.modulo,
    required this.topico,
  });

  @override
  Widget build(BuildContext context) {
    final total = topico.mockExercicios ?? 5;
    final nodes = List.generate(total, (i) {
      return TrailNode(
        titulo: 'Exercício ${i + 1}',
        desbloqueado: i == 0,
        concluido: false,
      );
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TrailStarfield()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.cream),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modulo.titulo.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                topico.titulo,
                                style: const TextStyle(
                                  color: AppColors.cream,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.muted.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.science_outlined,
                              color: AppColors.muted, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pré-visualização de UI — sem perguntas reais '
                              'cadastradas ainda para este tópico.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ExerciseTrail(
                  nodes: nodes,
                  onNodeTap: (index) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Pré-visualização — este nó ainda não tem '
                          'pergunta real por trás.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/curriculum.dart';
import '../../domain/providers/game_path_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/exercise_trail.dart';
import 'exercise_screen.dart';

/// Rótulos e mensagens específicos de cada categoria de trilha —
/// 'fixacao' (padrão), 'extra' (caminho opcional de Exercícios) ou
/// 'prova' (Prova final). Mesma tela, três contextos.
class _CategoriaInfo {
  final String label; // usado no cabeçalho, ex: "FIXAÇÃO"
  final String vazio; // mensagem quando não há perguntas cadastradas

  const _CategoriaInfo({required this.label, required this.vazio});
}

const _categorias = {
  'fixacao': _CategoriaInfo(
    label: 'FIXAÇÃO',
    vazio: 'Nenhum exercício cadastrado ainda.',
  ),
  'extra': _CategoriaInfo(
    label: 'EXERCÍCIOS',
    vazio: 'Nenhum exercício extra cadastrado ainda.',
  ),
  'prova': _CategoriaInfo(
    label: 'PROVA FINAL',
    vazio: 'Nenhuma questão de prova cadastrada ainda.',
  ),
};

/// Trilha de exercícios individuais de um tópico — é o que abre quando o
/// aluno toca em "Fixação", "Exercícios" (caminho opcional) ou "Prova
/// final" no Mapa. As três levam à mesma tela, diferenciadas só pela
/// [categoria] passada.
///
/// Fonte do dado:
/// - `topico.implementado`: busca a trilha REAL via `gamePathProvider`,
///   passando `topico.id` e [categoria] explicitamente — ligada às
///   perguntas cadastradas no Supabase com esse mesmo `topico` +
///   `categoria` ('fixacao', 'extra' ou 'prova').
/// - Caso contrário, usa `topico.mockExercicios` pra gerar uma trilha de
///   pré-visualização local — sem API, sem pergunta real — só pra já dar
///   pra navegar e ver a UI funcionando. O modo de pré-visualização hoje
///   só existe para 'fixacao'; Exercícios/Prova de tópicos ainda não
///   implementados continuam abrindo o placeholder genérico (ver
///   map_screen.dart) em vez desta tela.
///
/// Pra marcar um novo tópico como real: (1) cadastre as perguntas no
/// Supabase com `topico` igual ao `id` do tópico em curriculum.dart e a
/// `categoria` certa para cada uma, e (2) troque `mockExercicios` por
/// `implementado: true` nesse mesmo `TopicoInfo`. Nada mais precisa
/// mudar aqui.
class TopicExercisesScreen extends ConsumerStatefulWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;
  final String categoria;

  const TopicExercisesScreen({
    super.key,
    required this.modulo,
    required this.topico,
    this.categoria = 'fixacao',
  });

  @override
  ConsumerState<TopicExercisesScreen> createState() =>
      _TopicExercisesScreenState();
}

class _TopicExercisesScreenState extends ConsumerState<TopicExercisesScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.topico.implementado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(gamePathProvider.notifier).loadGamePath(
              topico: widget.topico.id,
              categoria: widget.categoria,
            );
      });
    }
  }

  _CategoriaInfo get _info =>
      _categorias[widget.categoria] ?? _categorias['fixacao']!;

  @override
  Widget build(BuildContext context) {
    final modulo = widget.modulo;
    final topico = widget.topico;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TrailStarfield()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    modulo: modulo,
                    topico: topico,
                    label: _info.label,
                  ),
                ),
                if (topico.implementado)
                  ..._buildRealSlivers(context)
                else
                  ..._buildMockSlivers(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRealSlivers(BuildContext context) {
    final pathState = ref.watch(gamePathProvider);

    if (pathState.isLoading) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ];
    }
    if (pathState.errorMessage != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pathState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.cream),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    onPressed: () => ref.read(gamePathProvider.notifier).loadGamePath(
                          topico: widget.topico.id,
                          categoria: widget.categoria,
                          forceReload: true,
                        ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (pathState.nodes.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(
              _info.vazio,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      ];
    }

    final nodes = pathState.nodes
        .map((n) => TrailNode(
              titulo: n.titulo,
              desbloqueado: n.desbloqueado,
              concluido: n.concluido,
            ))
        .toList();
    return [
      ExerciseTrail(
        nodes: nodes,
        onNodeTap: (i) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ExerciseScreen(nodeIndex: i)),
        ),
      ),
    ];
  }

  List<Widget> _buildMockSlivers(BuildContext context) {
    final total = widget.topico.mockExercicios ?? 5;
    final nodes = List.generate(
      total,
      (i) => TrailNode(
        titulo: 'Exercício ${i + 1}',
        desbloqueado: i == 0,
        concluido: false,
      ),
    );
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.muted.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined, color: AppColors.muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pré-visualização de UI — sem perguntas reais '
                    'cadastradas ainda para este tópico.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ExerciseTrail(
        nodes: nodes,
        onNodeTap: (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pré-visualização — este nó ainda não tem pergunta real por trás.',
            ),
          ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;
  final String label;

  const _Header({
    required this.modulo,
    required this.topico,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.cream),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${modulo.titulo.toUpperCase()} · $label',
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
    );
  }
}
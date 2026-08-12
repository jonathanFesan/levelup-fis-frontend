import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/curriculo_model.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/capitulo_progress_provider.dart';
import '../../domain/providers/curriculo_provider.dart';
import '../../domain/providers/exam_provider.dart';
import '../../domain/providers/topic_progress_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/exercise_trail.dart';
import '../widgets/module_strip.dart';
import 'curiosidade_screen.dart';
import 'exam_stats_screen.dart';
import 'resumo_screen.dart';
import 'topic_exercises_screen.dart';

/// Tela de Mapa — agora mostra o módulo Mecânica inteiro numa única
/// página rolável, tópico por tópico.
///
/// Para cada tópico: um banner (módulo pequeno/discreto + tópico grande,
/// estilo "Seção X, Unidade Y") seguido de uma trilha SEQUENCIAL — os
/// Capítulos do Bloco (Resumo, Curiosidade(s), Fixação, Prova — nessa
/// ou em qualquer outra ordem definida pelo painel), um atrás do outro,
/// cada um travando o próximo até ser concluído, cada tipo com seu
/// próprio ícone (ver _iconeCapitulo). O único que fica FORA dessa
/// sequência é o Capítulo tipo 'extra' (Exercícios): um selo pequeno,
/// sem curva/cometa, ANEXADO ao canto inferior direito do nó de
/// Fixação — ver TrailNode.sideBadge em widgets/exercise_trail.dart e
/// _buildTopicPathSlivers.
///
/// FASE 2 DO CURRÍCULO DINÂMICO: antes disso, o caminho era um desenho
/// fixo de 4 nós com curvas feitas à mão (só Resumo→Fixação→Prova,
/// Exercícios ao lado) — não dava pra encaixar Curiosidade NO MEIO do
/// caminho nesse esquema. Trocado pela mesma trilha vertical sequencial
/// já usada dentro de cada Capítulo de exercícios (ExerciseTrail, ver
/// widgets/exercise_trail.dart), que já sabe lidar com qualquer
/// quantidade de nós.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Mensagem exibida ao tocar em um módulo (Termologia, Ondulatória
  /// etc.) que o aluno ainda não desbloqueou — Item 5 do refinamento.
  void _mostrarModuloBloqueado(ModuloInfo modulo) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_rounded, color: AppColors.gold, size: 32),
        title: const Text(
          'Quase lá!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.cream, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Você ainda não chegou aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final curriculoAsync = ref.watch(curriculoProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TrailStarfield()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _TopStats(
                    joules: userState.user?.joules ?? 0,
                    fotons: userState.user?.fotons ?? 0,
                    cargas: userState.user?.cargas ?? 0,
                    onProfileTap: () => context.go('/profile'),
                  ),
                ),
                ...curriculoAsync.when(
                  loading: () => const [
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    ),
                  ],
                  error: (e, _) => [
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Erro ao carregar o currículo.',
                                style: TextStyle(color: AppColors.cream),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    ref.invalidate(curriculoProvider),
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  data: (modulos) => _buildCurriculoSlivers(modulos),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppNavTab.mapa,
        onSelect: (tab) {
          switch (tab) {
            case AppNavTab.mapa:
              _scrollToTop();
              break;
            case AppNavTab.videos:
              context.go('/videos');
              break;
            case AppNavTab.perfil:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }

  /// Monta a faixa de módulos + a lista de tópicos do módulo Mecânica
  /// (único com conteúdo hoje) a partir do currículo já carregado.
  List<Widget> _buildCurriculoSlivers(List<ModuloInfo> modulos) {
    final currentModulo = modulos.firstWhere(
      (m) => m.id == 'mecanica',
      orElse: () => const ModuloInfo(
        id: 'mecanica',
        titulo: 'Mecânica',
        emoji: '⚙️',
        topicos: [],
      ),
    );

    return [
      SliverToBoxAdapter(
        child: ModuleStrip(
          modulos: modulos,
          onModuleTap: (modulo) {
            if (modulo.id == currentModulo.id) {
              _scrollToTop();
              return;
            }
            if (modulo.navegavel) {
              // Outro módulo já navegável (nenhum caso disso hoje além
              // de Mecânica, mas deixa pronto pro dia em que houver
              // mais de um módulo com conteúdo real ao mesmo tempo).
              return;
            }
            _mostrarModuloBloqueado(modulo);
          },
        ),
      ),
      for (final topico in currentModulo.topicos) ...[
        if (ref.watch(topicoDesbloqueadoProvider(topico.id)).valueOrNull ==
            true) ...[
          SliverToBoxAdapter(
            child: _TopicBanner(
              modulo: currentModulo,
              topico: topico,
            ),
          ),
          ..._buildTopicPathSlivers(currentModulo, topico),
        ] else
          SliverToBoxAdapter(
            child: _TopicoBloqueadoCard(
              modulo: currentModulo,
              topico: topico,
            ),
          ),
      ],
    ];
  }

  /// Monta a trilha sequencial de um tópico: todos os Capítulos exceto
  /// 'extra', na ordem definida pelo painel (`ordem`), cada um travando
  /// o próximo até ser concluído — mesma mecânica de sempre (Resumo,
  /// Fixação) estendida a Curiosidade (ver
  /// capitulo_progress_provider.dart) e Prova (via examAttemptsProvider,
  /// concluída = pelo menos uma tentativa finalizada). 'extra'
  /// (Exercícios) é o único que fica de fora, como ramificação opcional
  /// abaixo — sempre existiu como opcional, só mudou de posição visual.
  List<Widget> _buildTopicPathSlivers(ModuloInfo modulo, TopicoInfo topico) {
    final progresso = ref.watch(topicProgressProvider(topico.id)).valueOrNull;
    final capProgresso =
        ref.watch(capituloProgressProvider(topico.id)).valueOrNull ?? {};
    final tentativasAsync = ref.watch(examAttemptsProvider(topico.id));
    final provaConcluida = tentativasAsync.maybeWhen(
      data: (tentativas) => tentativas.any((t) => t.finalizada),
      orElse: () => false,
    );

    bool concluidoDoTipo(CapituloModel c) {
      switch (c.tipo) {
        case 'resumo':
          return progresso?.resumoConcluido ?? false;
        case 'fixacao':
          return progresso?.fixacaoConcluida ?? false;
        case 'prova':
          return provaConcluida;
        case 'curiosidade':
          return capProgresso[c.id] ?? false;
        default:
          return false;
      }
    }

    final sequencia = [
      ...topico.capitulos.where((c) => c.tipo != 'extra'),
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));

    // Exercícios (extra) não faz parte da sequência principal — vira um
    // selo pequeno ANEXADO ao nó de Fixação (canto inferior direito),
    // sem curva/cometa ligando a ele. Só existe se o Bloco tiver um
    // Capítulo tipo 'extra' cadastrado no painel (aba Currículo — se não
    // aparecer aqui, é porque esse Capítulo ainda não foi criado lá).
    final extraCapitulo = topico.capituloDoTipo('extra');
    final extraDesbloqueado = progresso?.fixacaoConcluida ?? false;

    final slivers = <Widget>[];

    if (sequencia.isEmpty) {
      // Bloco recém-criado pelo painel, ainda sem nenhum Capítulo
      // cadastrado — não deveria acontecer com Blocos migrados pela
      // 011_capitulos_livres.sql, mas evita uma tela em branco.
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'O conteúdo deste tópico ainda está sendo preparado.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ),
      );
    } else {
      final nodes = [
        for (var i = 0; i < sequencia.length; i++)
          TrailNode(
            titulo: sequencia[i].titulo,
            desbloqueado: i == 0 || concluidoDoTipo(sequencia[i - 1]),
            concluido: concluidoDoTipo(sequencia[i]),
            icon: _iconeCapitulo(sequencia[i].tipo),
            sideBadge: (sequencia[i].tipo == 'fixacao' && extraCapitulo != null)
                ? TrailSideBadge(
                    icon: _iconeCapitulo('extra'),
                    desbloqueado: extraDesbloqueado,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TopicExercisesScreen(
                          modulo: modulo,
                          topico: topico,
                          categoria: 'extra',
                          tituloCapitulo: extraCapitulo.titulo,
                        ),
                      ),
                    ),
                    onTapBloqueado: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Conclua a Fixação para desbloquear.'),
                      ),
                    ),
                  )
                : null,
          ),
      ];
      slivers.add(
        ExerciseTrail(
          nodes: nodes,
          onNodeTap: (i) => _abrirCapitulo(modulo, topico, sequencia[i]),
        ),
      );
    }

    return slivers;
  }

  /// Ícone de cada tipo de Capítulo, usado tanto nos nós da sequência
  /// principal quanto no selo de Exercícios extra.
  IconData _iconeCapitulo(String tipo) {
    switch (tipo) {
      case 'resumo':
        return Icons.menu_book_rounded;
      case 'fixacao':
        return Icons.edit_note_rounded;
      case 'prova':
        return Icons.emoji_events_rounded;
      case 'curiosidade':
        return Icons.lightbulb_outline_rounded;
      case 'extra':
        // "+" — Exercícios extra é conteúdo A MAIS, fora da sequência
        // principal (ver o selo anexado ao nó de Fixação, abaixo).
        return Icons.add_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  void _abrirCapitulo(
    ModuloInfo modulo,
    TopicoInfo topico,
    CapituloModel capitulo,
  ) {
    switch (capitulo.tipo) {
      case 'resumo':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResumoScreen(modulo: modulo, topico: topico),
          ),
        );
        break;
      case 'fixacao':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TopicExercisesScreen(
              modulo: modulo,
              topico: topico,
              categoria: 'fixacao',
              tituloCapitulo: capitulo.titulo,
            ),
          ),
        );
        break;
      case 'prova':
        // Sempre pela tela de Estatísticas, mesmo sem nenhuma tentativa
        // ainda (ela já lida com isso) — evita ExamScreen ser aberta às
        // vezes direto do mapa, às vezes via estatísticas, o que fazia a
        // tela de resultado não saber pra onde voltar (ver
        // exam_screen.dart).
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamStatsScreen(modulo: modulo, topico: topico),
          ),
        );
        break;
      case 'curiosidade':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CuriosidadeScreen(
              modulo: modulo,
              topico: topico,
              capitulo: capitulo,
            ),
          ),
        );
        break;
    }
  }
}

/// Banner de destaque do tópico — estilo "Seção X, Unidade Y" do
/// Duolingo: módulo pequeno e discreto em cima, tópico grande e em
/// negrito embaixo. Puramente informativo agora (não navega mais pra
/// lugar nenhum — o conteúdo já está logo abaixo, na mesma tela).
class _TopicBanner extends StatelessWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const _TopicBanner({required this.modulo, required this.topico});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gold, AppColors.goldDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Módulo: menos destacado (menor, mais discreto).
            Text(
              modulo.titulo.toUpperCase(),
              style: TextStyle(
                color: AppColors.bg.withValues(alpha: 0.65),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            // Tópico: bem mais destacado (maior, em negrito).
            Text(
              topico.titulo,
              style: const TextStyle(
                color: AppColors.bg,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O caminho de 4 nós de um tópico: Resumo → Fixação → Prova conectados
/// por curvas suaves (mesmo estilo Bézier da trilha principal), com
/// Exercícios ao lado como ramificação opcional a partir de Fixação —
/// também conectada por uma curva, não uma linha reta.
///
/// Como as curvas precisam ser desenhadas com precisão entre os centros
/// dos nós, este widget usa posicionamento absoluto (Stack + Positioned)
/// em vez de Column/Row — os pontos-âncora abaixo definem tanto onde os
/// nós ficam quanto onde a curva passa.
/// Mostrado no lugar do banner + mini-caminho de um tópico quando ele
/// ainda está bloqueado — o capítulo anterior do módulo (mesmo
/// ModuloInfo, ordem vinda de curriculoProvider) ainda não teve a
/// Fixação concluída.
/// Ver topicoDesbloqueadoProvider em topic_progress_provider.dart pra
/// regra completa (só tópicos com implementado=true entram nessa
/// sequência — os de mockExercicios continuam livres, são ferramenta
/// de teste).
class _TopicoBloqueadoCard extends StatelessWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const _TopicoBloqueadoCard({required this.modulo, required this.topico});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lockedFill,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.muted, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topico.titulo,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Conclua a Fixação do capítulo anterior para desbloquear.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho de estatísticas do Mapa — Joules, Fótons e Cargas
/// (nomenclatura temática; ver documento de Economia e Nomenclatura e
/// user_model.dart, que expõe esses mesmos valores como getters em cima
/// de xp/moedas/vidas).
class _TopStats extends StatelessWidget {
  final int joules;
  final int fotons;
  final int cargas;
  final VoidCallback onProfileTap;

  const _TopStats({
    required this.joules,
    required this.fotons,
    required this.cargas,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(
            icon: Icons.bolt_rounded,
            color: AppColors.gold,
            value: '$joules J',
          ),
          _StatItem(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.goldDeep,
            value: '$fotons',
          ),
          _StatItem(
            icon: Icons.battery_full_rounded,
            color: const Color(0xFF7FD8E8),
            value: '$cargas',
          ),
          GestureDetector(
            onTap: onProfileTap,
            child: const Icon(
              Icons.account_circle_rounded,
              color: AppColors.muted,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.cream,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// Barra de navegação inferior (Mapa/Vídeos/Perfil) foi extraída para
// ../widgets/app_bottom_nav_bar.dart nesta sessão, porque ProfileScreen
// e a nova VideosScreen também precisam dela — ver esse arquivo.
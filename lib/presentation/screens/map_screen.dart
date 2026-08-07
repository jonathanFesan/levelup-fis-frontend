import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/curriculum.dart';
import '../../domain/providers/exam_provider.dart';
import '../../domain/providers/topic_progress_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/exercise_trail.dart' show TrailStarfield;
import '../widgets/module_strip.dart';
import 'exam_stats_screen.dart';
import 'placeholder_section_screen.dart';
import 'resumo_screen.dart';
import 'topic_exercises_screen.dart';

/// Tela de Mapa — agora mostra o módulo Mecânica inteiro numa única
/// página rolável, tópico por tópico.
///
/// Para cada tópico: um banner (módulo pequeno/discreto + tópico grande,
/// estilo "Seção X, Unidade Y") seguido de um caminho com 4 nós:
///
/// ```
///        (Resumo)
///           |
///   (Fixação) - - (Exercícios)   <- ramificação opcional, ao lado
///           |
///        (Prova)
/// ```
///
/// - Resumo e Prova final ainda não têm design definido: abrem uma
///   pré-visualização genérica (PlaceholderSectionScreen).
/// - Fixação abre a trilha de exercícios de verdade daquele tópico
///   (TopicExercisesScreen) — para Cinemática isso já é real, vindo do
///   Supabase; para os demais tópicos de Mecânica é pré-visualização
///   (ver TopicoInfo.mockExercicios em curriculum.dart). É esse o ponto
///   que precisa ser conferido conforme mais tópicos ganharem perguntas
///   reais no backend.
/// - Exercícios (o caminho opcional) ainda não tem conteúdo/design
///   definido nenhum: abre a mesma pré-visualização genérica de
///   Resumo/Prova, por enquanto.
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

    // O Mapa mostra o módulo Mecânica inteiro (único com conteúdo hoje).
    final currentModulo = kCurriculo.firstWhere((m) => m.id == 'mecanica');

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
                SliverToBoxAdapter(
                  child: ModuleStrip(
                    onModuleTap: (modulo) {
                      if (modulo.id == currentModulo.id) {
                        _scrollToTop();
                        return;
                      }
                      if (modulo.navegavel) {
                        // Outro módulo já navegável (nenhum caso disso
                        // hoje além de Mecânica, mas deixa pronto pro
                        // dia em que houver mais de um módulo com
                        // conteúdo real ao mesmo tempo).
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
                    SliverToBoxAdapter(
                      child: _TopicMetaPath(
                        modulo: currentModulo,
                        topico: topico,
                      ),
                    ),
                  ] else
                    SliverToBoxAdapter(
                      child: _TopicoBloqueadoCard(
                        modulo: currentModulo,
                        topico: topico,
                      ),
                    ),
                ],
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
/// ModuloInfo, ordem de kCurriculo) ainda não teve a Fixação concluída.
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

class _TopicMetaPath extends ConsumerWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;

  const _TopicMetaPath({required this.modulo, required this.topico});

  // Deslocamentos horizontais (a partir do centro) e verticais (a partir
  // do topo) de cada nó — mesma unidade usada pelo _MetaPathPainter pra
  // desenhar as curvas exatamente até esses pontos.
  static const double _fixacaoOffsetX = -55;
  static const double _exerciciosOffsetX = 78;
  static const double _resumoY = 40;
  static const double _fixacaoRowY = 170;
  static const double _provaY = 300;
  static const double _nodeColumnWidth = 100;
  static const double _containerHeight = 372;

  void _abrirPlaceholder(BuildContext context, String secao, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceholderSectionScreen(
          moduloTitulo: modulo.titulo,
          topicoTitulo: topico.titulo,
          secaoTitulo: secao,
          icon: icon,
        ),
      ),
    );
  }

  /// Abre a trilha real de exercícios pra [categoria] ('fixacao', 'extra'
  /// ou 'prova') se o tópico já tiver conteúdo implementado; caso
  /// contrário, cai no placeholder genérico — não faz sentido abrir uma
  /// trilha "de mentira" pra Prova/Exercícios extras de um tópico que
  /// ainda nem tem Fixação real.
  void _abrirCategoria(
    BuildContext context,
    String categoria,
    String secaoTitulo,
    IconData icon,
  ) {
    if (topico.implementado) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TopicExercisesScreen(
            modulo: modulo,
            topico: topico,
            categoria: categoria,
          ),
        ),
      );
    } else {
      _abrirPlaceholder(context, secaoTitulo, icon);
    }
  }

  /// Abre o Resumo — tela real (com o bônus de +10 J idempotente) pra
  /// tópicos implementados; placeholder genérico pros demais, igual
  /// já era feito pra Prova/Exercícios não implementados.
  void _abrirResumo(BuildContext context) {
    if (!topico.implementado) {
      _abrirPlaceholder(context, 'Resumo', Icons.menu_book_rounded);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResumoScreen(modulo: modulo, topico: topico),
      ),
    );
  }

  /// Abre a Prova — sempre pela tela de Estatísticas, mesmo se ainda não
  /// tiver nenhuma tentativa (ela já lida com isso: mostra "nenhuma
  /// tentativa ainda" + botão "Tentar novamente"). Unificar a entrada
  /// assim evita ExamScreen ser aberta às vezes direto do mapa, às vezes
  /// via estatísticas — o que causava a tela de resultado não saber pra
  /// onde voltar depois de finalizar (ver exam_screen.dart).
  void _abrirProva(BuildContext context) {
    if (!topico.implementado) {
      _abrirPlaceholder(context, 'Prova final', Icons.emoji_events_rounded);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamStatsScreen(modulo: modulo, topico: topico),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: _containerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;

          Widget positionedNode({
            required double x,
            required double y,
            required double radius,
            required Widget child,
          }) {
            return Positioned(
              left: x - _nodeColumnWidth / 2,
              top: y - radius,
              width: _nodeColumnWidth,
              child: child,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Curvas desenhadas atrás dos nós.
              Positioned.fill(
                child: CustomPaint(
                  painter: _MetaPathPainter(centerX: centerX),
                ),
              ),
              positionedNode(
                x: centerX,
                y: _resumoY,
                radius: 34,
                child: _MetaNode(
                  icon: Icons.menu_book_rounded,
                  label: 'Resumo',
                  onTap: () => _abrirResumo(context),
                ),
              ),
              positionedNode(
                x: centerX + _fixacaoOffsetX,
                y: _fixacaoRowY,
                radius: 34,
                child: _MetaNode(
                  icon: Icons.edit_note_rounded,
                  label: 'Fixação',
                  onTap: () => _abrirCategoria(
                      context, 'fixacao', 'Fixação', Icons.edit_note_rounded),
                ),
              ),
              positionedNode(
                x: centerX + _exerciciosOffsetX,
                y: _fixacaoRowY,
                radius: 28,
                child: _MetaNode(
                  icon: Icons.bolt_rounded,
                  label: 'Exercícios',
                  optional: true,
                  onTap: () => _abrirCategoria(
                      context, 'extra', 'Exercícios', Icons.bolt_rounded),
                ),
              ),
              positionedNode(
                x: centerX,
                y: _provaY,
                radius: 34,
                child: _ProvaNode(
                  topicoId: topico.id,
                  onTap: () => _abrirProva(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Desenha as 3 curvas do mini-caminho: Resumo→Fixação e Fixação→Prova
/// como S-curves verticais (igual à trilha principal), e Fixação→
/// Exercícios como um arco suave lateral — nunca uma linha reta.
class _MetaPathPainter extends CustomPainter {
  final double centerX;

  _MetaPathPainter({required this.centerX});

  @override
  void paint(Canvas canvas, Size size) {
    final fixacaoX = centerX + _TopicMetaPath._fixacaoOffsetX;
    final exerciciosX = centerX + _TopicMetaPath._exerciciosOffsetX;
    const resumoY = _TopicMetaPath._resumoY;
    const rowY = _TopicMetaPath._fixacaoRowY;
    const provaY = _TopicMetaPath._provaY;

    final mainPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final branchPaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Resumo -> Fixação: S-curve vertical.
    _drawDashed(
      canvas,
      mainPaint,
      Path()
        ..moveTo(centerX, resumoY)
        ..cubicTo(centerX, (resumoY + rowY) / 2, fixacaoX,
            (resumoY + rowY) / 2, fixacaoX, rowY),
    );

    // Fixação -> Prova: S-curve vertical, simétrica à anterior.
    _drawDashed(
      canvas,
      mainPaint,
      Path()
        ..moveTo(fixacaoX, rowY)
        ..cubicTo(fixacaoX, (rowY + provaY) / 2, centerX,
            (rowY + provaY) / 2, centerX, provaY),
    );

    // Fixação -> Exercícios: arco suave lateral (ramificação opcional).
    _drawDashed(
      canvas,
      branchPaint,
      Path()
        ..moveTo(fixacaoX, rowY)
        ..cubicTo(fixacaoX + 45, rowY + 30, exerciciosX - 45, rowY + 30,
            exerciciosX, rowY),
    );
  }

  void _drawDashed(Canvas canvas, Paint paint, Path path) {
    const dashWidth = 7.0;
    const dashGap = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MetaPathPainter oldDelegate) =>
      oldDelegate.centerX != centerX;
}

/// Envolve o _MetaNode da Prova com um badge de check dourado no canto
/// quando o tópico já tem pelo menos uma tentativa concluída (consulta
/// examAttemptsProvider, com cache do próprio Riverpod — não refaz a
/// chamada toda hora que o mapa reconstrói).
class _ProvaNode extends ConsumerWidget {
  final String topicoId;
  final VoidCallback onTap;

  const _ProvaNode({required this.topicoId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tentativasAsync = ref.watch(examAttemptsProvider(topicoId));
    final concluida = tentativasAsync.maybeWhen(
      data: (tentativas) => tentativas.any((t) => t.finalizada),
      orElse: () => false,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _MetaNode(
          icon: Icons.emoji_events_rounded,
          label: 'Prova',
          onTap: onTap,
        ),
        if (concluida)
          const Positioned(
            top: -2,
            right: 8,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.success,
              child: Icon(Icons.check_rounded, size: 14, color: AppColors.bg),
            ),
          ),
      ],
    );
  }
}

/// Um dos 4 nós do caminho (Resumo, Fixação, Prova, Exercícios). Todos
/// ficam sempre "disponíveis" visualmente — não há estado de
/// bloqueado/concluído neste nível (isso só existe dentro da trilha real
/// de exercícios, atrás do nó Fixação). EXCEÇÃO: o nó da Prova ganhou um
/// badge de concluído nesta sessão — ver _ProvaNode acima, que envolve
/// este widget em vez de alterá-lo.
class _MetaNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool optional;

  const _MetaNode({
    required this.icon,
    required this.label,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = optional ? 56.0 : 68.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: optional
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.gold, AppColors.goldDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: optional ? AppColors.card : null,
                border: optional
                    ? Border.all(
                        color: AppColors.muted.withValues(alpha: 0.4),
                        width: 1.4,
                      )
                    : null,
                boxShadow: optional
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Icon(
                icon,
                color: optional ? AppColors.muted : AppColors.bg,
                size: optional ? 22 : 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: optional ? AppColors.muted : AppColors.cream,
            fontWeight: FontWeight.w700,
            fontSize: optional ? 11.5 : 13,
          ),
        ),
        if (optional)
          const Text(
            'opcional',
            style: TextStyle(color: AppColors.muted, fontSize: 9.5),
          ),
      ],
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
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dado mínimo que a trilha precisa pra desenhar um nó. Tanto o Mapa real
/// (alimentado pela API, via MapNode) quanto telas de teste/preview
/// (dado estático local) convertem seus dados pra isso.
class TrailNode {
  final String titulo;
  final bool desbloqueado;
  final bool concluido;

  /// Ícone mostrado no nó enquanto ele está desbloqueado e ainda não
  /// concluído (o estado "atual"). Se nulo, cai no ícone genérico de
  /// sempre (play_arrow) — usado pelas trilhas de pergunta individual,
  /// que não têm um ícone por nó. Nó bloqueado sempre mostra cadeado;
  /// concluído sempre mostra check — [icon] não muda esses dois estados.
  final IconData? icon;

  /// Selo pequeno, ancorado no canto inferior direito do nó, pra uma
  /// ramificação OPCIONAL que não faz parte da sequência principal —
  /// hoje só o Capítulo "Exercícios" (extra) usa isto, anexado ao nó de
  /// Fixação. Diferente dos nós da sequência, não tem curva/cometa
  /// ligando ele a nada (ver map_screen.dart).
  final TrailSideBadge? sideBadge;

  const TrailNode({
    required this.titulo,
    required this.desbloqueado,
    required this.concluido,
    this.icon,
    this.sideBadge,
  });
}

/// Selo satélite de um [TrailNode] — botão menor, sem conexão visual com
/// a trilha principal (ver doc de [TrailNode.sideBadge]).
class TrailSideBadge {
  final IconData icon;
  final bool desbloqueado;
  final VoidCallback onTap;

  /// Chamado no lugar de [onTap] quando [desbloqueado] é false — em vez
  /// de o toque simplesmente não fazer nada, dá feedback do motivo
  /// (mesma filosofia dos nós principais).
  final VoidCallback? onTapBloqueado;

  const TrailSideBadge({
    required this.icon,
    required this.desbloqueado,
    required this.onTap,
    this.onTapBloqueado,
  });
}

/// Fundo de estrelas discreto — usado atrás de qualquer tela com a mesma
/// identidade visual (Mapa, telas de teste de trilha, etc).
class TrailStarfield extends StatelessWidget {
  const TrailStarfield({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarfieldPainter());
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7); // seed fixa = padrão estável entre rebuilds
    final paint = Paint()..color = AppColors.cream.withValues(alpha: 0.25);
    final dotCount = (size.width * size.height / 9000).clamp(40, 220).toInt();
    for (var i = 0; i < dotCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextBool() ? 0.8 : 1.4;
      paint.color = AppColors.cream.withValues(
        alpha: random.nextDouble() * 0.25 + 0.08,
      );
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}

/// A trilha de nós em si — pensada pra ser usada DIRETO dentro de uma
/// lista de `slivers` de um CustomScrollView (ela mesma já é um sliver).
///
/// Recebe só a lista de [TrailNode] e desenha tudo: curva suave entre os
/// nós, cometa animado no trecho até o nó atual, glow pulsante no nó
/// atual. Quem usa este widget decide de onde vêm os dados (API real ou
/// dado estático de teste) — a trilha não sabe a diferença.
class ExerciseTrail extends StatelessWidget {
  final List<TrailNode> nodes;
  final void Function(int index)? onNodeTap;

  const ExerciseTrail({super.key, required this.nodes, this.onNodeTap});

  @override
  Widget build(BuildContext context) {
    final currentIndex = nodes.indexWhere(
      (n) => n.desbloqueado && !n.concluido,
    );

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final node = nodes[index];
            final previousNode = index > 0 ? nodes[index - 1] : null;
            final isCurrent = index == currentIndex;
            final offset = _nodeOffsetFor(index);

            return Column(
              children: [
                if (previousNode != null)
                  _CometConnector(
                    startOffset: _nodeOffsetFor(index - 1),
                    endOffset: offset,
                    completed: previousNode.concluido,
                    animate: isCurrent,
                    height: 76,
                  ),
                _TrailNodeTile(
                  node: node,
                  isCurrent: isCurrent,
                  xOffset: offset,
                  animationDelay: Duration(milliseconds: 60 * index),
                  onTap: node.desbloqueado && onNodeTap != null
                      ? () => onNodeTap!(index)
                      : null,
                ),
              ],
            );
          },
          childCount: nodes.length,
        ),
      ),
    );
  }
}

/// Duração de um ciclo completo do cometa (do nó concluído até o nó
/// atual) — compartilhada com o glow do nó atual (_TrailNodeTileState),
/// pra que o brilho do nó pulse mais forte exatamente quando o cometa
/// chega, e vá reduzindo até o próximo ciclo (quando o cometa "chega"
/// de novo). Mais lenta que antes (era 1800ms) a pedido do usuário.
const Duration _kCometCycle = Duration(milliseconds: 3400);

/// Deslocamento horizontal (em pixels, a partir do centro) de cada nó.
/// Alterna entre -[_curveAmplitude] e +[_curveAmplitude] para formar uma
/// onda suave — em vez de uma coluna perfeitamente reta.
const double _curveAmplitude = 38.0;

double _nodeOffsetFor(int index) =>
    index.isEven ? -_curveAmplitude : _curveAmplitude;

/// Trecho entre dois nós. Em vez de uma linha reta, desenha uma curva suave
/// (Bézier) entre o deslocamento horizontal de um nó e o do próximo. Por
/// padrão é só uma linha fina; quando [animate] é true (o trecho que leva
/// ao nó atual), ganha um cometa que desliza pela curva em loop.
class _CometConnector extends StatefulWidget {
  final double startOffset;
  final double endOffset;
  final bool completed;
  final bool animate;
  final double height;

  const _CometConnector({
    required this.startOffset,
    required this.endOffset,
    required this.completed,
    required this.animate,
    required this.height,
  });

  @override
  State<_CometConnector> createState() => _CometConnectorState();
}

class _CometConnectorState extends State<_CometConnector>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _CometConnector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O Flutter reaproveita este State por posição na lista (sem Key
    // único por nó) — então quando o progresso muda (um nó é concluído
    // e o "trecho até o atual" passa a ser outro), este MESMO State pode
    // continuar vivo, só que agora representando um trecho diferente.
    // Sem isso, o controller ficava travado no valor de `animate` da
    // primeira montagem (initState só roda uma vez), e o cometa nunca
    // aparecia no trecho certo depois que o progresso avançava.
    if (oldWidget.animate != widget.animate) {
      _syncController();
    }
  }

  void _syncController() {
    if (widget.animate && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: _kCometCycle,
      )..repeat();
    } else if (!widget.animate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Ponto (x, y) na curva cúbica para t em [0, 1] — os mesmos pontos de
  /// controle usados pelo _ConnectorPainter, para o cometa seguir a curva
  /// exatamente em vez de cortar caminho reto.
  Offset _pointOnCurve(double t, double centerX) {
    final p0 = Offset(centerX + widget.startOffset, 0);
    final c1 = Offset(centerX + widget.startOffset, widget.height * 0.5);
    final c2 = Offset(centerX + widget.endOffset, widget.height * 0.5);
    final p3 = Offset(centerX + widget.endOffset, widget.height);
    final mt = 1 - t;
    final x = mt * mt * mt * p0.dx +
        3 * mt * mt * t * c1.dx +
        3 * mt * t * t * c2.dx +
        t * t * t * p3.dx;
    final y = mt * mt * mt * p0.dy +
        3 * mt * mt * t * c1.dy +
        3 * mt * t * t * c2.dy +
        t * t * t * p3.dy;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.completed
        ? AppColors.gold.withValues(alpha: 0.7)
        : AppColors.muted.withValues(alpha: 0.25);

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        return SizedBox(
          height: widget.height,
          width: constraints.maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _ConnectorPainter(
                  startX: centerX + widget.startOffset,
                  endX: centerX + widget.endOffset,
                  height: widget.height,
                  color: lineColor,
                ),
              ),
              if (_controller != null)
                AnimatedBuilder(
                  animation: _controller!,
                  builder: (context, _) {
                    final point = _pointOnCurve(_controller!.value, centerX);

                    // Oscilação de brilho enquanto o cometa viaja — várias
                    // "piscadas" ao longo do trajeto, não intensidade fixa.
                    final flicker = 0.75 +
                        0.25 *
                            math.sin(_controller!.value * 2 * math.pi * 7);

                    return Positioned(
                      left: point.dx - 4.5,
                      top: point.dy - 4.5,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Núcleo quase branco (cometa "quente"), halo
                          // dourado por fora — em vez de dourado sólido.
                          color: Color.lerp(
                            AppColors.gold,
                            Colors.white,
                            0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: 0.75 * flicker,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: AppColors.gold.withValues(
                                alpha: 0.55 * flicker,
                              ),
                              blurRadius: 16 * flicker,
                              spreadRadius: 3 * flicker,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Desenha a curva Bézier (tracejada) que liga dois nós consecutivos.
class _ConnectorPainter extends CustomPainter {
  final double startX;
  final double endX;
  final double height;
  final Color color;

  _ConnectorPainter({
    required this.startX,
    required this.endX,
    required this.height,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(startX, height * 0.5, endX, height * 0.5, endX, height);

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
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.color != color;
  }
}

class _TrailNodeTile extends StatefulWidget {
  final TrailNode node;
  final bool isCurrent;
  final double xOffset;
  final Duration animationDelay;
  final VoidCallback? onTap;

  const _TrailNodeTile({
    required this.node,
    required this.isCurrent,
    required this.xOffset,
    required this.animationDelay,
    required this.onTap,
  });

  @override
  State<_TrailNodeTile> createState() => _TrailNodeTileState();
}

class _TrailNodeTileState extends State<_TrailNodeTile>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnim;
  AnimationController? _glowController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _entranceAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(widget.animationDelay, () {
      if (mounted) _entranceController.forward();
    });

    _syncGlowController();
  }

  @override
  void didUpdateWidget(covariant _TrailNodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mesmo motivo do _CometConnectorState: este State é reaproveitado
    // por posição na lista, então quando o nó "atual" muda de posição
    // (progresso avançou), o glow precisa ser criado/descartado aqui —
    // initState sozinho não é chamado de novo pra refletir isso.
    if (oldWidget.isCurrent != widget.isCurrent) {
      _syncGlowController();
    }
  }

  void _syncGlowController() {
    if (widget.isCurrent && _glowController == null) {
      // Mesma duração do cometa (_kCometCycle) e mesmo instante de início
      // (ambos criados durante a mesma passada de build da trilha), pra
      // que o pico de brilho coincida com o momento em que o cometa
      // chega — e depois vá reduzindo até o próximo ciclo, quando ele
      // "chega" de novo.
      _glowController = AnimationController(
        vsync: this,
        duration: _kCometCycle,
      )..repeat();
    } else if (!widget.isCurrent && _glowController != null) {
      _glowController!.dispose();
      _glowController = null;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;

    Widget circle = _TrailNodeCircle(node: node, onTap: widget.onTap);

    // Glow suave sobre o nó atual — é onde o "cometa" chega. Pico de
    // brilho logo no início de cada ciclo (instante em que o cometa
    // chega, que coincide com o fim do ciclo anterior do _CometConnector)
    // e decaimento gradual até o ciclo seguinte, formando o mesmo loop.
    if (_glowController != null) {
      circle = AnimatedBuilder(
        animation: _glowController!,
        builder: (context, child) {
          final t = _glowController!.value;
          final intensidade = Curves.easeOut.transform(1 - t);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(
                    alpha: 0.18 + (intensidade * 0.45),
                  ),
                  blurRadius: 16 + (intensidade * 32),
                  spreadRadius: 1 + (intensidade * 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: circle,
      );
    }

    // Selo satélite (ex: Exercícios extra) — separado do círculo
    // principal, no canto inferior direito, SEM curva/cometa ligando a
    // ele. Aplicado depois do glow, pra não distorcer o brilho (que fica
    // só ao redor do círculo principal).
    //
    // IMPORTANTE: o Stack precisa de um tamanho EXPLÍCITO grande o
    // bastante pra cobrir o selo — um Stack comum só herda o tamanho
    // dos filhos NÃO-Positioned (aqui, só o círculo, 72x72), e qualquer
    // Positioned que ultrapasse esse tamanho fica visível (Clip.none)
    // mas NÃO recebe toque: o hit-test de qualquer RenderBox para antes
    // de entrar nos filhos se o ponto cair fora do próprio `size` da
    // caixa. Por isso o círculo fica centralizado (Align) dentro dessa
    // caixa maior, em vez de Positioned(right: valor negativo) — assim
    // ele continua exatamente no mesmo lugar de sempre (a Column por
    // fora sempre centraliza pelo maior filho, então alargar esta caixa
    // não desloca o círculo em relação à curva/cometa).
    if (node.sideBadge != null) {
      const largura = 72.0 + 128.0;
      circle = SizedBox(
        width: largura,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(alignment: Alignment.center, child: circle),
            Positioned(
              right: 10,
              bottom: -4,
              child: _TrailSideBadgeButton(badge: node.sideBadge!),
            ),
          ],
        ),
      );
    }

    final tile = Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(widget.xOffset, 0),
        child: Column(
          children: [
            circle,
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: Text(
                node.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: node.desbloqueado && !node.concluido
                      ? AppColors.cream
                      : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _entranceAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _entranceAnim.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _entranceAnim.value)),
            child: child,
          ),
        );
      },
      child: tile,
    );
  }
}

class _TrailNodeCircle extends StatelessWidget {
  final TrailNode node;
  final VoidCallback? onTap;

  const _TrailNodeCircle({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const size = 72.0;

    if (node.concluido) {
      return Material(
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
              color: AppColors.card,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.gold.withValues(alpha: 0.55),
              size: 26,
            ),
          ),
        ),
      );
    }

    if (node.desbloqueado) {
      return Material(
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.gold, AppColors.goldDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              node.icon ?? Icons.play_arrow_rounded,
              color: AppColors.bg,
              size: 30,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lockedFill,
        border: Border.all(color: AppColors.card, width: 1.5),
      ),
      child: const Icon(
        Icons.lock_rounded,
        color: AppColors.muted,
        size: 24,
      ),
    );
  }
}

/// Botão menor do [TrailSideBadge] — ícone próprio, sem curva/cometa,
/// ancorado no canto do nó principal (ver _TrailNodeTileState.build).
class _TrailSideBadgeButton extends StatelessWidget {
  final TrailSideBadge badge;

  const _TrailSideBadgeButton({required this.badge});

  @override
  Widget build(BuildContext context) {
    const size = 38.0;

    return Material(
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: badge.desbloqueado ? badge.onTap : badge.onTapBloqueado,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: badge.desbloqueado ? AppColors.card : AppColors.lockedFill,
            border: Border.all(
              color: badge.desbloqueado
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : AppColors.divider,
              width: 1.6,
            ),
            boxShadow: badge.desbloqueado
                ? [
                    BoxShadow(
                      color: AppColors.bg.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            badge.desbloqueado ? badge.icon : Icons.lock_rounded,
            color: badge.desbloqueado ? AppColors.gold : AppColors.muted,
            size: 18,
          ),
        ),
      ),
    );
  }
}
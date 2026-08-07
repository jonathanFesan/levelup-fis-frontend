import 'package:flutter/material.dart';

/// Um tópico dentro de um módulo (ex: "Cinemática" dentro de "Mecânica").
class TopicoInfo {
  final String id;
  final String titulo;

  /// Se já existe conteúdo real (questões cadastradas no backend) para
  /// este tópico. Hoje só `cinematica` tem isso.
  final bool implementado;

  /// Quantidade de nós de teste/preview pra essa trilha, usado SÓ PARA
  /// TESTAR A UI quando o tópico ainda não tem perguntas reais no
  /// backend. Se preenchido (e `implementado` for false), o tópico abre
  /// uma trilha com esse número de nós falsos (sem pergunta de verdade
  /// por trás) em vez de aparecer bloqueado como "Em breve".
  ///
  /// Isto é só uma ferramenta de teste visual — remover (deixar null)
  /// quando o tópico ganhar conteúdo real de verdade.
  final int? mockExercicios;

  /// Nível GLOBAL mínimo (profiles.nivel) que o aluno precisa ter para
  /// abrir este tópico — trava por nível, somada à trava por sequência
  /// (tópico anterior do mesmo módulo com Fixação concluída, ver
  /// topicoDesbloqueadoProvider em topic_progress_provider.dart). As
  /// DUAS regras precisam valer juntas: nível mínimo E sequência
  /// completa (decisão confirmada com o responsável do produto).
  ///
  /// Valores abaixo são um ponto de partida razoável para o MVP (só
  /// Introdução e Cinemática têm conteúdo real hoje) — ajuste livremente
  /// conforme o ritmo real dos alunos for observado.
  final int nivelMinimo;

  const TopicoInfo({
    required this.id,
    required this.titulo,
    this.implementado = false,
    this.mockExercicios,
    this.nivelMinimo = 1,
  });

  /// Se este tópico pode ser aberto (com conteúdo real OU em modo de
  /// teste/preview).
  bool get navegavel => implementado || mockExercicios != null;
}

/// Um "bloco grande" do currículo (ex: Mecânica, Termologia...).
class ModuloInfo {
  final String id;
  final String titulo;
  final IconData? icon;

  /// Usado só quando não há um Material Icon que represente bem o módulo
  /// (ex: ímã, átomo) — nesse caso desenhamos um ícone customizado.
  final Widget Function(Color color, double size)? customIconBuilder;

  final List<TopicoInfo> topicos;

  const ModuloInfo({
    required this.id,
    required this.titulo,
    this.icon,
    this.customIconBuilder,
    required this.topicos,
  });

  /// Um módulo é considerado "com conteúdo real" se pelo menos um dos
  /// seus tópicos já está implementado no backend.
  bool get implementado => topicos.any((t) => t.implementado);

  /// Um módulo fica navegável na faixa de módulos se tiver pelo menos um
  /// tópico navegável (real OU em modo de teste).
  bool get navegavel => topicos.any((t) => t.navegavel);
}

/// Currículo completo (blocos grandes), na ordem pedida.
///
/// IMPORTANTE: isto é dado estático no app, não vem do backend. Hoje o
/// Supabase só tem o tópico `cinematica` populado (10 questões, dentro do
/// MVP). Todo o resto aparece no app como roadmap — visível, mas bloqueado
/// — até que exista conteúdo real para desbloquear. Quando o backend tiver
/// mais tópicos/módulos, dá pra trocar isso por uma chamada de API sem
/// mudar a UI que consome essa lista.
///
/// Os tópicos de Mecânica abaixo com `mockExercicios` preenchido não têm
/// pergunta real nenhuma por trás — servem só pra ver o fluxo de
/// navegação (Módulo → Tópico → Exercícios) antes do conteúdo existir.
/// ATUALIZADO nesta sessão: como o app agora vai para teste real com
/// alunos, esses tópicos de mentira deixaram de ficar liberados pra
/// todo mundo — só aparecem navegáveis para a conta admin (ver
/// `UserModel.isAdmin` / `topicoDesbloqueadoProvider`). Para alunos
/// reais, eles ficam bloqueados como qualquer tópico sem conteúdo.
const List<ModuloInfo> kCurriculo = [
  ModuloInfo(
    id: 'mecanica',
    titulo: 'Mecânica',
    icon: Icons.settings_rounded, // engrenagem
    topicos: [
      TopicoInfo(
        id: 'introducao',
        titulo: 'Introdução à Física',
        implementado: true,
        nivelMinimo: 1,
      ),
      TopicoInfo(
        id: 'cinematica',
        titulo: 'Cinemática',
        implementado: true,
        nivelMinimo: 2,
      ),
      TopicoInfo(
        id: 'dinamica',
        titulo: 'Dinâmica',
        mockExercicios: 8,
        nivelMinimo: 3,
      ),
      TopicoInfo(
        id: 'estatica',
        titulo: 'Estática',
        mockExercicios: 6,
        nivelMinimo: 4,
      ),
      TopicoInfo(
        id: 'fluidos',
        titulo: 'Fluidos',
        mockExercicios: 7,
        nivelMinimo: 5,
      ),
    ],
  ),
  ModuloInfo(
    id: 'termologia',
    titulo: 'Termologia',
    icon: Icons.local_fire_department_rounded, // fogo
    topicos: [],
  ),
  ModuloInfo(
    id: 'ondulatoria',
    titulo: 'Ondulatória',
    icon: Icons.graphic_eq_rounded, // seno/cosseno
    topicos: [],
  ),
  ModuloInfo(
    id: 'optica',
    titulo: 'Óptica',
    icon: Icons.change_history_rounded, // prisma de Newton
    topicos: [],
  ),
  ModuloInfo(
    id: 'eletricidade',
    titulo: 'Eletricidade',
    icon: Icons.bolt_rounded, // raio
    topicos: [],
  ),
  ModuloInfo(
    id: 'magnetismo',
    titulo: 'Magnetismo',
    customIconBuilder: _magnetIcon, // ímã (sem Material Icon equivalente)
    topicos: [],
  ),
  ModuloInfo(
    id: 'eletromagnetismo',
    titulo: 'Eletromagnetismo',
    icon: Icons.electrical_services_rounded, // motor elétrico
    topicos: [],
  ),
  ModuloInfo(
    id: 'fisica_moderna',
    titulo: 'Física Moderna',
    customIconBuilder: _atomIcon, // átomo, no estilo da logo
    topicos: [],
  ),
];

/// Desenho minimalista de um ímã em ferradura — não existe um Material
/// Icon equivalente, então desenhamos um pequeno SVG-like via CustomPaint.
Widget _magnetIcon(Color color, double size) {
  return CustomPaint(
    size: Size(size, size),
    painter: _MagnetPainter(color: color),
  );
}

class _MagnetPainter extends CustomPainter {
  final Color color;
  const _MagnetPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(w * 0.18, h * 0.1, w * 0.64, h * 0.85);

    // "U" do ímã.
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.top + rect.height * 0.55)
      ..arcToPoint(
        Offset(rect.right, rect.top + rect.height * 0.55),
        radius: Radius.circular(rect.width / 2),
        clockwise: false,
      )
      ..lineTo(rect.right, rect.top);
    canvas.drawPath(path, paint);

    // Pontas (polos) destacadas.
    final tipPaint = Paint()..color = color;
    canvas.drawCircle(Offset(rect.left, rect.top), size.width * 0.08, tipPaint);
    canvas.drawCircle(
      Offset(rect.right, rect.top),
      size.width * 0.08,
      tipPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MagnetPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Átomo simples (núcleo + 2 órbitas elípticas), no mesmo espírito do
/// ícone da logo do app.
Widget _atomIcon(Color color, double size) {
  return CustomPaint(
    size: Size(size, size),
    painter: _AtomPainter(color: color),
  );
}

class _AtomPainter extends CustomPainter {
  final Color color;
  const _AtomPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (final angle in [-0.6, 0.0, 0.6]) {
      canvas.save();
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.92,
          height: size.height * 0.42,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(center, size.width * 0.09, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AtomPainter oldDelegate) =>
      oldDelegate.color != color;
}
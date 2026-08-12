// Teste do widget de trilha (widgets/exercise_trail.dart) — cobre as
// duas novidades pedidas: ícone por nó (Resumo/Fixação/Prova/Curiosidade
// cada um com o seu) e o selo lateral (Exercícios extra, anexado ao nó
// de Fixação, sem curva ligando a ele, liberado só depois da Fixação).
//
// Puramente de widget — sem Riverpod nem rede, então não precisa mockar
// providers/backend: só monta ExerciseTrail direto com TrailNode
// estáticos, do jeito que map_screen.dart monta a partir do currículo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:levelup_fis/presentation/widgets/exercise_trail.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [child]),
      ),
    );
  }

  // Cada nó agenda sua animação de entrada com Future.delayed (ver
  // _TrailNodeTileState.initState em exercise_trail.dart) — sem avançar
  // o relógio do teste depois do pumpWidget, esse timer fica pendente e
  // o framework de teste falha a asserção "!timersPending" no fim do
  // teste, mesmo o widget já tendo o que precisamos verificar.
  Future<void> pumpTrail(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(wrap(child));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('cada nó mostra o ícone do seu tipo de Capítulo',
      (tester) async {
    final nodes = [
      const TrailNode(
        titulo: 'Resumo',
        desbloqueado: true,
        concluido: false,
        icon: Icons.menu_book_rounded,
      ),
      const TrailNode(
        titulo: 'Fixação',
        desbloqueado: false,
        concluido: false,
        icon: Icons.edit_note_rounded,
      ),
    ];

    await pumpTrail(tester, ExerciseTrail(nodes: nodes));

    // Nó desbloqueado (Resumo) mostra o ícone customizado, não o
    // play_arrow genérico.
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    // Nó bloqueado (Fixação) mostra cadeado, independente do `icon`
    // informado — locked sempre ganha.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsNothing);
  });

  testWidgets('nó sem icon cai no ícone genérico de sempre (play_arrow)',
      (tester) async {
    const nodes = [
      TrailNode(titulo: 'Fase 1', desbloqueado: true, concluido: false),
    ];

    await pumpTrail(tester, const ExerciseTrail(nodes: nodes));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets(
      'selo lateral (Exercícios extra) bloqueado: mostra cadeado e não '
      'chama onTap, só onTapBloqueado', (tester) async {
    var tapLiberado = 0;
    var tapBloqueado = 0;

    final nodes = [
      TrailNode(
        titulo: 'Fixação',
        desbloqueado: true,
        concluido: false,
        icon: Icons.edit_note_rounded,
        sideBadge: TrailSideBadge(
          icon: Icons.bolt_rounded,
          desbloqueado: false,
          onTap: () => tapLiberado++,
          onTapBloqueado: () => tapBloqueado++,
        ),
      ),
    ];

    await pumpTrail(tester, ExerciseTrail(nodes: nodes));

    // Bloqueado: mostra cadeado no selo (2 cadeados na tela não rola
    // aqui pq o nó principal está desbloqueado — só o selo é bloqueado).
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pump();

    expect(tapBloqueado, 1);
    expect(tapLiberado, 0);
  });

  testWidgets(
      'selo lateral (Exercícios extra) liberado: mostra o ícone próprio '
      'e chama onTap ao tocar', (tester) async {
    var tapLiberado = 0;
    var tapBloqueado = 0;

    final nodes = [
      TrailNode(
        titulo: 'Fixação',
        desbloqueado: true,
        concluido: true,
        icon: Icons.edit_note_rounded,
        sideBadge: TrailSideBadge(
          icon: Icons.bolt_rounded,
          desbloqueado: true,
          onTap: () => tapLiberado++,
          onTapBloqueado: () => tapBloqueado++,
        ),
      ),
    ];

    await pumpTrail(tester, ExerciseTrail(nodes: nodes));

    // Liberado: selo mostra o próprio ícone (bolt), não cadeado.
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bolt_rounded));
    await tester.pump();

    expect(tapLiberado, 1);
    expect(tapBloqueado, 0);
  });

  testWidgets('nó sem sideBadge não desenha nenhum selo extra',
      (tester) async {
    const nodes = [
      TrailNode(
        titulo: 'Resumo',
        desbloqueado: true,
        concluido: false,
        icon: Icons.menu_book_rounded,
      ),
    ];

    await pumpTrail(tester, const ExerciseTrail(nodes: nodes));

    // Só o ícone do nó principal — nada de bolt/cadeado extra de selo.
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });
}

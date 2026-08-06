// Teste padrão gerado pelo Flutter — ajustado para o app real.
//
// Como o app carrega .env e providers do Supabase no main(), um smoke
// test completo do app inteiro exigiria mockar essas dependências.
// Por enquanto, este teste apenas garante que o widget raiz
// (LevelUpFisApp) constrói sem lançar exceção, dentro de um
// ProviderScope isolado.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:levelup_fis/main.dart';

void main() {
  testWidgets('LevelUpFisApp constrói sem erros', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LevelUpFisApp()),
    );

    // A tela inicial é a de Login (initialLocation: '/login').
    expect(find.text('LevelUp Fís'), findsOneWidget);
  });
}
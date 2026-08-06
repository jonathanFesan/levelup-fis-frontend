import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';

/// Ponto de entrada — LevelUp Fís.
///
/// 1. Carrega o .env (SUPABASE_URL, SUPABASE_ANON_KEY) antes de qualquer
///    outra coisa, já que repositories/services dependem dessas variáveis.
/// 2. Envolve o app em ProviderScope para que todos os providers
///    (auth, user, gamePath, router) funcionem.
/// 3. Usa MaterialApp.router com o routerProvider (GoRouter) da Fase 6.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(const ProviderScope(child: LevelUpFisApp()));
}

class LevelUpFisApp extends ConsumerWidget {
  const LevelUpFisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );

    return MaterialApp.router(
      title: 'LevelUp Fís',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: GoogleFonts.nunitoTextTheme(),
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
        ),
      ),
    );
  }
}

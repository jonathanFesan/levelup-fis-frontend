import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/progress_model.dart';
import '../../domain/providers/auth_provider.dart';
import '../../presentation/screens/exercise_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/map_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/register_screen.dart';
import '../../presentation/screens/result_screen.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/videos_screen.dart';

/// Configuração de navegação — LevelUp Fís (Fase 6).
///
/// Regras de proteção de rota:
/// - Ao abrir o app, fica em /splash enquanto authProvider tenta
///   restaurar uma sessão salva (authState.isRestaurando) — ver
///   auth_provider.dart. Evita piscar a tela de login antes de saber
///   se dá pra restaurar sem pedir email/senha de novo.
/// - Usuário não logado tentando acessar qualquer rota protegida
///   (map, exercise, result, profile, videos) é redirecionado para
///   /login.
/// - Usuário já logado tentando acessar /login ou /register é
///   redirecionado direto para /map.
///
/// routerProvider escuta o authProvider para que o GoRouter reavalie o
/// redirect automaticamente quando o estado de login mudar (ex: logout).
final routerProvider = Provider<GoRouter>((ref) {
  // Observa o authProvider para que o router seja reconstruído
  // (e o redirect reavaliado) quando o estado de login mudar.
  ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final indoParaAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final noSplash = state.matchedLocation == '/splash';

      // Ainda tentando restaurar sessão salva — segura em /splash,
      // não decide nada de login/logout até isso terminar.
      if (authState.isRestaurando) {
        return noSplash ? null : '/splash';
      }

      if (!authState.isLoggedIn && !indoParaAuth) {
        return '/login';
      }
      if (authState.isLoggedIn && (indoParaAuth || noSplash)) {
        return '/map';
      }
      if (!authState.isLoggedIn && noSplash) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/exercise',
        builder: (context, state) {
          final nodeIndex = state.extra as int? ?? 0;
          return ExerciseScreen(nodeIndex: nodeIndex);
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final resultado = state.extra as AnswerResultModel;
          return ResultScreen(resultado: resultado);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/videos',
        builder: (context, state) => const VideosScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Rota não encontrada: ${state.uri}'),
      ),
    ),
  );
});

/// Faz a ponte entre o estado do Riverpod (authProvider) e o
/// Listenable que o GoRouter espera em `refreshListenable`, para que
/// o router re-execute o `redirect` sempre que login/logout OU o fim
/// da restauração de sessão (isRestaurando) mudarem.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      if (previous?.isLoggedIn != next.isLoggedIn ||
          previous?.isRestaurando != next.isRestaurando) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
}
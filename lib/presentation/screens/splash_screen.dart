import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tela de Splash — mostrada só enquanto authProvider tenta restaurar
/// uma sessão salva (ver _restaurarSessao em auth_provider.dart). Não
/// tem lógica própria: o GoRouter (app_router.dart) redireciona pra
/// /map ou /login sozinho assim que a restauração termina, via
/// authState.isRestaurando.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }
}

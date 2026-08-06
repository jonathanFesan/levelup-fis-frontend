// Arquivo: frontend/lib/presentation/widgets/app_bottom_nav_bar.dart
// Barra de navegação inferior compartilhada — Mapa / Vídeos / Perfil.
//
// Extraída de map_screen.dart (onde vivia como as classes privadas
// _BottomNavBar/_NavTab/_NavBarItem) porque ProfileScreen e a nova
// VideosScreen também precisam dela agora.
//
// Navegação entre as três abas usa context.go(...) — /map, /videos e
// /profile são todas rotas de verdade do GoRouter. Isso é diferente da
// mistura GoRouter/Navigator descrita na seção 4.2 do handoff: aquela
// regra vale só para TopicExercisesScreen/ExerciseScreen/ResultScreen,
// que são empilhadas imperativamente por cima do GoRouter. Mapa, Vídeos
// e Perfil continuam navegando só por context.go.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppNavTab { mapa, videos, perfil }

class AppBottomNavBar extends StatelessWidget {
  final AppNavTab currentTab;
  final ValueChanged<AppNavTab> onSelect;

  const AppBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavBarItem(
                icon: Icons.map_rounded,
                label: 'Mapa',
                selected: currentTab == AppNavTab.mapa,
                onTap: () => onSelect(AppNavTab.mapa),
              ),
              _NavBarItem(
                icon: Icons.play_circle_rounded,
                label: 'Vídeos',
                selected: currentTab == AppNavTab.videos,
                onTap: () => onSelect(AppNavTab.videos),
              ),
              _NavBarItem(
                icon: Icons.person_rounded,
                label: 'Perfil',
                selected: currentTab == AppNavTab.perfil,
                onTap: () => onSelect(AppNavTab.perfil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

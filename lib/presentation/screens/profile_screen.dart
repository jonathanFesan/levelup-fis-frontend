import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';

/// Tela de Perfil — LevelUp Fís
///
/// Consome userProvider, mostra Joules, Fótons, Cargas e nível
/// (nomenclatura temática — mesmo dado de xp/moedas/vidas por baixo,
/// ver user_model.dart).
/// Inclui ação de logout via authProvider e uma seção de Configurações
/// (tema e notificações, via settingsProvider — ver esse arquivo pra
/// entender por que essas preferências são só locais por enquanto).
///
/// Nesta sessão: a seção de vídeos virou tela própria (VideosScreen,
/// rota /videos) em vez de ficar embutida aqui — o placeholder que
/// existia foi substituído pela seção de Configurações. A navegação
/// entre Mapa/Vídeos/Perfil agora usa a AppBottomNavBar compartilhada.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final user = userState.user;

    final xpNoNivel = (user?.xp ?? 0) % AppConstants.xpPorNivel;
    final progresso = xpNoNivel / AppConstants.xpPorNivel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userState.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Text(userState.errorMessage!,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              ref.read(userProvider.notifier).loadProfile(),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                'N${user?.nivel ?? 1}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              authState.email ?? user?.email ?? '',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nível ${user?.nivel ?? 1}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progresso.clamp(0, 1),
                          minHeight: 10,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$xpNoNivel / ${AppConstants.xpPorNivel} J para o próximo nível',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.battery_full_rounded,
                              color: Colors.amber.shade700,
                              label: 'Cargas',
                              value: '${user?.cargas ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.bolt_rounded,
                              color: Colors.deepPurpleAccent,
                              label: 'Joules',
                              value: '${user?.joules ?? 0} J',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.auto_awesome_rounded,
                              color: Colors.lightBlueAccent.shade700,
                              label: 'Fótons',
                              value: '${user?.fotons ?? 0}',
                            ),
                          ),
                        ],
                      ),
                      if ((user?.cargas ?? 0) < 5) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final ok = await ref
                                  .read(userProvider.notifier)
                                  .buyCharge();
                              if (!context.mounted) return;
                              final erro = ref.read(userProvider).errorMessage;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Carga comprada!'
                                        : (erro ?? 'Não foi possível comprar.'),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 18),
                            label: const Text('Comprar Carga · 20 Fótons'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Configurações',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _SettingsCard(),
                    ],
                  ),
                ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppNavTab.perfil,
        onSelect: (tab) {
          switch (tab) {
            case AppNavTab.mapa:
              context.go('/map');
              break;
            case AppNavTab.videos:
              context.go('/videos');
              break;
            case AppNavTab.perfil:
              break;
          }
        },
      ),
    );
  }
}

/// Card de Configurações — tema e notificações.
///
/// Consome settingsProvider (preferências locais do dispositivo, ver
/// domain/providers/settings_provider.dart). O toggle de tema aqui é só
/// "escuro/claro/sistema" salvo localmente; a UI do app hoje usa
/// AppColors fixo em várias telas (map_screen.dart, etc.) em vez do
/// Theme.of(context), então um tema "claro" de verdade exigiria revisar
/// essas telas também — fora do escopo desta sessão. Deixei o toggle
/// funcional e persistente, mas avisando isso pro time não se surpreender
/// se o restante do app não mudar de cor imediatamente.
class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Tema'),
            subtitle: Text(_temaLabel(settings.themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Escuro'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Claro'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Sistema'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(mode);
                }
              },
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notificações'),
            subtitle: const Text('Lembretes de estudo e novidades'),
            value: settings.notificationsEnabled,
            onChanged: (enabled) {
              ref
                  .read(settingsProvider.notifier)
                  .setNotificationsEnabled(enabled);
            },
          ),
        ],
      ),
    );
  }

  String _temaLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Escuro';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

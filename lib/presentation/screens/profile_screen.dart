import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';

/// Tela de Perfil — LevelUp Fís
///
/// Consome userProvider, mostra Joules, Fótons, Cargas e nível
/// (nomenclatura temática — mesmo dado de xp/moedas/vidas por baixo,
/// ver user_model.dart).
///
/// REESCRITA nesta sessão (Item 4 do refinamento pré-testes reais):
/// - Visual agora usa AppColors (mesma paleta dark de Mapa/Vídeos) em
///   vez do Theme.of(context) padrão do Material — a tela destoava do
///   resto do app antes disso.
/// - Mostra o nome de exibição do aluno (user.nomeExibicao) em vez do
///   e-mail, com edição inline (contas antigas não têm nome cadastrado
///   ainda — ver sql/007_nome_perfil.sql).
/// - Configurações: os controles de Tema e Notificações não tinham
///   efeito real nenhum no app (só salvavam uma preferência que nada
///   lia depois — ver settings_provider.dart). Em vez de manter uma UI
///   que parece funcionar mas não funciona, o Tema virou informativo
///   (o app é dark-only por design hoje) e Notificações ficou marcado
///   como "Em breve" — ambos documentados, nenhum finge fazer algo que
///   não faz. Ver nota em settings_provider.dart pra como ligar de
///   verdade no futuro.
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

  Future<void> _editarNome() async {
    final user = ref.read(userProvider).user;
    if (user == null) return;

    final controller = TextEditingController(
      text: (user.nome != null && user.nome!.trim().isNotEmpty)
          ? user.nome
          : '',
    );

    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Seu nome', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.cream),
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: 'Como podemos te chamar?',
            hintStyle: TextStyle(color: AppColors.muted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.gold),
            ),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (novoNome == null || novoNome.isEmpty || !mounted) return;

    final ok = await ref.read(userProvider.notifier).atualizarNome(novoNome);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o nome agora.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final user = userState.user;

    final xpNoNivel = (user?.xp ?? 0) % AppConstants.xpPorNivel;
    final progresso = xpNoNivel / AppConstants.xpPorNivel;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.cream,
        title: const Text('Perfil', style: TextStyle(color: AppColors.cream)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.muted),
            tooltip: 'Sair',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: userState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : userState.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          userState.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.cream),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.bg,
                          ),
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
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.gold, AppColors.goldDeep],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'N${user?.nivel ?? 1}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.bg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _editarNome,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user?.nomeExibicao ?? '',
                                    style: const TextStyle(
                                      color: AppColors.cream,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_rounded,
                                      size: 16, color: AppColors.muted),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nível ${user?.nivel ?? 1}',
                              style: const TextStyle(color: AppColors.muted),
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
                          backgroundColor: AppColors.lockedFill,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$xpNoNivel / ${AppConstants.xpPorNivel} J para o próximo nível',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.battery_full_rounded,
                              color: const Color(0xFF7FD8E8),
                              label: 'Cargas',
                              value: '${user?.cargas ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.bolt_rounded,
                              color: AppColors.gold,
                              label: 'Joules',
                              value: '${user?.joules ?? 0} J',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.auto_awesome_rounded,
                              color: AppColors.goldDeep,
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
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gold,
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 18),
                            label: const Text('Comprar Carga · 20 Fótons'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      const Text(
                        'Configurações',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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

/// Card de Configurações — Tema e Notificações.
///
/// Tema: o app usa uma paleta escura fixa (AppColors) em todas as
/// telas hoje — não existe tema claro implementado de verdade ainda,
/// então em vez de expor um seletor que não muda nada visualmente,
/// isto mostra o estado real de forma honesta.
///
/// Notificações: ainda não existe nenhum sistema de notificação por
/// trás (nem local, nem push) — o toggle antigo salvava uma preferência
/// que nada lia depois. Marcado "Em breve" até essa funcionalidade
/// existir de verdade.
class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.dark_mode_outlined, color: AppColors.muted),
            title: Text('Tema', style: TextStyle(color: AppColors.cream)),
            subtitle: Text(
              'Escuro (padrão do app, por enquanto)',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Opacity(
            opacity: 0.55,
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined,
                  color: AppColors.muted),
              title: const Text('Notificações',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text(
                'Em breve — lembretes de estudo e novidades',
                style: TextStyle(color: AppColors.muted),
              ),
              value: settings.notificationsEnabled,
              activeColor: AppColors.gold,
              onChanged: null,
            ),
          ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Arquivo: frontend/lib/domain/providers/settings_provider.dart
// Preferências locais do dispositivo — tema e notificações.
//
// DECISÃO DE ESCOPO (verificar com o time se ainda faz sentido no
// futuro): não existe coluna nem tabela no Supabase para preferências de
// usuário, e o handoff não menciona nenhuma. Em vez de inventar uma
// tabela nova sem confirmar com o time, essas preferências ficam só no
// dispositivo (via shared_preferences) — não sincronizam entre
// aparelhos nem persistem se o app for desinstalado.
//
// Se decidirem que precisa persistir no backend, o caminho seria: (1)
// coluna `tema` / `notificacoes_ativas` em `profiles`, (2) endpoint em
// profile.py pra ler/gravar, (3) trocar SharedPreferences por
// GameRepository aqui dentro, mantendo a mesma interface pública
// (SettingsState / SettingsNotifier) pra não quebrar quem usa.
//
// Requer a dependência `shared_preferences` no pubspec.yaml (adicionar
// se ainda não existir: `flutter pub add shared_preferences`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'settings.themeMode'; // 'light' | 'dark' | 'system'
const _kNotificationsKey = 'settings.notificationsEnabled';

class SettingsState {
  final ThemeMode themeMode;
  final bool notificationsEnabled;

  SettingsState({
    this.themeMode = ThemeMode.dark, // hoje o app é visualmente dark-only
    this.notificationsEnabled = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_kThemeModeKey);
    final notifications = prefs.getBool(_kNotificationsKey);

    state = state.copyWith(
      themeMode: _themeModeFromString(themeStr) ?? state.themeMode,
      notificationsEnabled: notifications ?? state.notificationsEnabled,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsKey, enabled);
  }

  ThemeMode? _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

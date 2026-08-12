// Arquivo: frontend/lib/domain/providers/auth_provider.dart
// Gerencia o estado de autenticação do usuário
//
// Atualizado nesta sessão: a sessão agora persiste entre aberturas do
// app. login()/register() salvam accessToken + refreshToken no
// shared_preferences; ao criar o AuthNotifier (ou seja, assim que o app
// abre — routerProvider já lê authProvider na primeira build),
// _restaurarSessao() tenta trocar um refreshToken salvo por uma sessão
// nova via POST /auth/refresh, sem pedir email/senha de novo. Só volta
// pra tela de login se não houver token salvo, ou se ele também já
// tiver expirado/sido revogado.
//
// isRestaurando começa true e só vira false depois dessa tentativa —
// o GoRouter (app_router.dart) usa esse campo pra segurar o app numa
// tela de splash em vez de piscar a tela de login antes de saber se dá
// pra restaurar.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:levelup_fis/data/repositories/auth_repository.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';

const _kAccessTokenKey = 'auth.accessToken';
const _kRefreshTokenKey = 'auth.refreshToken';
const _kUserIdKey = 'auth.userId';
const _kEmailKey = 'auth.email';

// Estado da autenticação
class AuthState {
  final bool isLoading;
  final bool isRestaurando;
  final bool isLoggedIn;
  final String? userId;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isRestaurando = true,
    this.isLoggedIn = false,
    this.userId,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isRestaurando,
    bool? isLoggedIn,
    String? userId,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isRestaurando: isRestaurando ?? this.isRestaurando,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      errorMessage: errorMessage,
    );
  }
}

// Notifier que controla as ações de auth
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final GameRepository _gameRepository;

  AuthNotifier(this._authRepository, this._gameRepository) : super(AuthState()) {
    _restaurarSessao();
  }

  Future<void> _salvarSessao({
    required String accessToken,
    required String? refreshToken,
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_kRefreshTokenKey, refreshToken);
    }
    await prefs.setString(_kUserIdKey, userId);
    await prefs.setString(_kEmailKey, email);
  }

  Future<void> _limparSessaoSalva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kEmailKey);
  }

  /// Roda uma vez, ao abrir o app. Tenta restaurar a sessão a partir do
  /// refreshToken salvo — se não der certo (não existe, expirou, foi
  /// revogado), simplesmente libera o app pra cair na tela de login,
  /// sem mostrar nenhum erro pro usuário (é o fluxo normal de "nunca
  /// logou" ou "sessão realmente expirou").
  Future<void> _restaurarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_kRefreshTokenKey);

    if (refreshToken == null) {
      state = state.copyWith(isRestaurando: false);
      return;
    }

    try {
      final data = await _authRepository.refresh(refreshToken);
      await _salvarSessao(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: data['user_id'],
        email: data['email'],
      );
      state = state.copyWith(
        isRestaurando: false,
        isLoggedIn: true,
        userId: data['user_id'],
        email: data['email'],
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
    } catch (e) {
      await _limparSessaoSalva();
      state = state.copyWith(isRestaurando: false);
    }
  }

  /// Realiza o login
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _authRepository.login(email, password);
      await _salvarSessao(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        userId: data['user_id'],
        email: data['email'],
      );
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        userId: data['user_id'],
        email: data['email'],
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  //// Realiza o cadastro
  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _authRepository.register(email, password);

      // O token vem da própria resposta de /auth/register (sign_up já
      // devolve uma sessão com access_token quando a confirmação de
      // e-mail está desativada no Supabase).
      final String? accessToken = data['access_token'];
      if (accessToken == null) {
        throw Exception(
          'Cadastro criado, mas sem sessão ativa (confirmação de e-mail pode '
          'estar exigida no Supabase). Faça login após confirmar o e-mail.',
        );
      }

      // Cria o perfil do usuário no banco após cadastro
      await _gameRepository.createProfile(
        data['user_id'],
        data['email'],
        accessToken,
      );

      await _salvarSessao(
        accessToken: accessToken,
        refreshToken: data['refresh_token'],
        userId: data['user_id'],
        email: data['email'],
      );

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        userId: data['user_id'],
        email: data['email'],
        accessToken: accessToken,
        refreshToken: data['refresh_token'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Dispara o e-mail de redefinição de senha (Supabase Auth). Não mexe
  /// no AuthState de sessão (isLoggedIn etc.) — é uma ação independente,
  /// disparável a partir da tela de Login sem afetar o formulário.
  /// Devolve null em caso de sucesso, ou a mensagem de erro.
  Future<String?> forgotPassword(String email) async {
    try {
      await _authRepository.forgotPassword(email);
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Realiza o logout
  void logout() {
    _limparSessaoSalva();
    state = AuthState(isRestaurando: false);
  }
}

// Provider global de autenticação
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository(), GameRepository());
});

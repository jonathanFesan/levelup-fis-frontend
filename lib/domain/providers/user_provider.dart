// Arquivo: frontend/lib/domain/providers/user_provider.dart
// Gerencia XP, moedas e vidas do usuário logado (Joules/Fótons/Cargas
// na tela — ver documento "Economia e Nomenclatura").
//
// Atualizado nesta sessão: todo método que chama o GameRepository agora
// lê authState.accessToken e passa adiante, já que o backend exige o
// header Authorization em /profile/*.
//
// Atualizado de novo agora: removeVida() não decrementa mais
// localmente e manda o número pronto via PATCH — as Cargas recarregam
// sozinhas com o tempo no backend (progress.py), então só o servidor
// sabe o valor certo. removeVida() agora chama POST
// /profile/{id}/lose-charge e substitui o UserModel inteiro pela
// resposta (pode vir com Cargas recarregadas desde a última checagem).
// Também ganhou buyCharge() — comprar 1 Carga de emergência com Fótons.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/core/constants/app_constants.dart';
import 'package:levelup_fis/data/models/user_model.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

// Estado do usuário
class UserState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  UserState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  UserState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final GameRepository _gameRepository;
  final Ref _ref;

  UserNotifier(this._gameRepository, this._ref) : super(UserState());

  /// Carrega o perfil do usuário logado
  Future<void> loadProfile() async {
    final authState = _ref.read(authProvider);
    if (authState.userId == null || authState.accessToken == null) return;

    // DIAGNÓSTICO TEMPORÁRIO — confirma exatamente o que está sendo
    // enviado na URL /profile/{user_id}.
    debugPrint('[loadProfile] userId enviado: "${authState.userId}"');

    state = state.copyWith(isLoading: true);
    try {
      final user = await _gameRepository.getProfile(
        authState.userId!,
        authState.accessToken!,
      );
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      // DIAGNÓSTICO TEMPORÁRIO — remover depois de achar a causa raiz.
      debugPrint('[loadProfile] erro real: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar perfil.',
      );
    }
  }

  /// Adiciona XP e moedas após acerto
  Future<void> addReward(int xpGanho, int moedasGanhas) async {
    final authState = _ref.read(authProvider);
    if (authState.userId == null ||
        authState.accessToken == null ||
        state.user == null) {
      return;
    }

    final novoXp = state.user!.xp + xpGanho;
    final novasMoedas = state.user!.moedas + moedasGanhas;

    // Verifica se subiu de nível (a cada 100 XP)
    final novoNivel = (novoXp / AppConstants.xpPorNivel).floor() + 1;

    // Atualiza localmente primeiro (feedback imediato)
    state = state.copyWith(
      user: state.user!.copyWith(
        xp: novoXp,
        moedas: novasMoedas,
        nivel: novoNivel,
      ),
    );

    // Sincroniza com o backend
    await _gameRepository.updateProfile(
      authState.userId!,
      authState.accessToken!,
      xp: novoXp,
      moedas: novasMoedas,
    );
  }

  /// Debita 1 Carga ao errar. Agora é o backend quem decide o valor
  /// final (recalcula recarga automática antes de debitar) — não
  /// decrementa mais localmente antes de sincronizar.
  Future<void> removeVida() async {
    final authState = _ref.read(authProvider);
    if (authState.userId == null ||
        authState.accessToken == null ||
        state.user == null) {
      return;
    }

    try {
      final userAtualizado = await _gameRepository.loseCharge(
        authState.userId!,
        authState.accessToken!,
      );
      state = state.copyWith(user: userAtualizado);
    } catch (e) {
      // Falha silenciosa por enquanto — mantém o valor local anterior.
      // Na próxima loadProfile() o valor certo volta a sincronizar.
    }
  }

  /// Compra 1 Carga de emergência com Fótons. Devolve true se deu
  /// certo; em caso de erro (Fótons insuficientes, Cargas já cheias),
  /// guarda a mensagem do backend em errorMessage e devolve false.
  Future<bool> buyCharge() async {
    final authState = _ref.read(authProvider);
    if (authState.userId == null ||
        authState.accessToken == null ||
        state.user == null) {
      return false;
    }

    try {
      final userAtualizado = await _gameRepository.buyCharge(
        authState.userId!,
        authState.accessToken!,
      );
      state = state.copyWith(user: userAtualizado, errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Atualiza o nome de exibição do usuário (Item 4 do refinamento:
  /// Perfil deve mostrar nome, não e-mail — como contas antigas não têm
  /// nome cadastrado, a edição acontece direto na tela de Perfil em vez
  /// de exigir recadastro). Atualiza local primeiro (feedback imediato)
  /// e sincroniza com o backend; devolve false silenciosamente em caso
  /// de erro de rede, mesma política de removeVida() acima.
  Future<bool> atualizarNome(String nome) async {
    final authState = _ref.read(authProvider);
    if (authState.userId == null ||
        authState.accessToken == null ||
        state.user == null) {
      return false;
    }

    // Guarda o UserModel inteiro (não só o nome) para poder reverter:
    // copyWith não consegue voltar um campo para null (padrão
    // `campo ?? this.campo`), então não dá pra reverter só o nome se o
    // valor antigo era null — precisa restaurar o objeto inteiro.
    final userAntigo = state.user!;
    state = state.copyWith(user: userAntigo.copyWith(nome: nome));

    try {
      await _gameRepository.updateProfile(
        authState.userId!,
        authState.accessToken!,
        nome: nome,
      );
      return true;
    } catch (e) {
      state = state.copyWith(user: userAntigo);
      return false;
    }
  }

  /// Reflete os totais que o BACKEND já calculou (joulesTotais,
  /// fotonsTotais, nivelAtual — vindos de AnswerResultModel após
  /// responder uma questão). Não soma nada aqui — desde que
  /// POST /questions/answer passou a aplicar a recompensa direto no
  /// perfil (retry pela metade, bônus de conclusão de capítulo, etc.),
  /// somar de novo no cliente contaria a recompensa duas vezes. Isso
  /// substitui o antigo addReward() pra esse fluxo — addReward() continua
  /// existindo só por compatibilidade, mas não deveria mais ser chamado
  /// depois de responder uma questão (ver exercise_screen.dart).
  void atualizarTotais({
    required int joules,
    required int fotons,
    required int nivel,
  }) {
    if (state.user == null) return;
    state = state.copyWith(
      user: state.user!.copyWith(xp: joules, moedas: fotons, nivel: nivel),
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(GameRepository(), ref);
});

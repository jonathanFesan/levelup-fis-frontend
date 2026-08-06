// Arquivo: frontend/lib/domain/providers/exam_provider.dart
// Gerencia a tentativa de Prova em andamento (questões, respostas em
// memória até confirmar, navegação livre entre questões, cronômetro
// total e por questão) e o histórico de tentativas por tópico.
//
// Diferente de game_path_provider.dart: aqui NADA é enviado ao backend
// pergunta por pergunta — o aluno pode responder, mudar de ideia e
// pular entre questões livremente, e só no fim (finalizar()) tudo vai
// pro servidor de uma vez pra correção.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/models/exam_attempt_model.dart';
import 'package:levelup_fis/data/models/question_model.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

class ExamState {
  final bool isLoading;
  final String? errorMessage;
  final int? attemptId;
  final String topico;
  final String modo; // 'facil' | 'dificil'
  final List<QuestionModel> questoes;
  final Map<int, String> respostas; // índice da questão -> resposta
  final int questaoAtual;
  final bool finalizando;
  final bool finalizada;
  final Map<String, dynamic>? resultado; // resposta crua de /exam/{id}/finish

  ExamState({
    this.isLoading = false,
    this.errorMessage,
    this.attemptId,
    this.topico = '',
    this.modo = 'facil',
    this.questoes = const [],
    this.respostas = const {},
    this.questaoAtual = 0,
    this.finalizando = false,
    this.finalizada = false,
    this.resultado,
  });

  bool get todasRespondidas =>
      questoes.isNotEmpty && respostas.length == questoes.length;

  ExamState copyWith({
    bool? isLoading,
    String? errorMessage,
    int? attemptId,
    String? topico,
    String? modo,
    List<QuestionModel>? questoes,
    Map<int, String>? respostas,
    int? questaoAtual,
    bool? finalizando,
    bool? finalizada,
    Map<String, dynamic>? resultado,
  }) {
    return ExamState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      attemptId: attemptId ?? this.attemptId,
      topico: topico ?? this.topico,
      modo: modo ?? this.modo,
      questoes: questoes ?? this.questoes,
      respostas: respostas ?? this.respostas,
      questaoAtual: questaoAtual ?? this.questaoAtual,
      finalizando: finalizando ?? this.finalizando,
      finalizada: finalizada ?? this.finalizada,
      resultado: resultado ?? this.resultado,
    );
  }
}

class ExamNotifier extends StateNotifier<ExamState> {
  final GameRepository _gameRepository;
  final Ref _ref;

  // Cronômetro fica fora do ExamState de propósito: não precisa
  // reconstruir a UI a cada segundo (a tela usa seu próprio
  // Timer.periodic só pra exibir o relógio). Isso aqui é a fonte da
  // verdade enviada ao backend em finalizar().
  final Stopwatch _cronometroTotal = Stopwatch();
  final Map<int, int> _tempoPorQuestaoSegundos = {};
  DateTime? _entrouNaQuestaoEm;

  ExamNotifier(this._gameRepository, this._ref) : super(ExamState());

  Future<bool> iniciar({required String topico, required String modo}) async {
    final accessToken = _ref.read(authProvider).accessToken;
    if (accessToken == null) {
      state = state.copyWith(
        errorMessage: 'Sessão expirada. Faça login novamente.',
      );
      return false;
    }

    state = ExamState(isLoading: true, topico: topico, modo: modo);
    try {
      final resultado = await _gameRepository.startExam(
        accessToken,
        topico: topico,
        modo: modo,
      );
      state = state.copyWith(
        isLoading: false,
        attemptId: resultado.attemptId,
        questoes: resultado.questoes,
      );
      _cronometroTotal
        ..reset()
        ..start();
      _tempoPorQuestaoSegundos.clear();
      _entrouNaQuestaoEm = DateTime.now();
      return true;
    } catch (e) {
      // DIAGNÓSTICO TEMPORÁRIO — remover depois de achar a causa raiz.
      debugPrint('[exam.iniciar] erro real: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao iniciar a prova.',
      );
      return false;
    }
  }

  void _registrarTempoQuestaoAtual() {
    if (_entrouNaQuestaoEm == null) return;
    final decorrido = DateTime.now().difference(_entrouNaQuestaoEm!).inSeconds;
    _tempoPorQuestaoSegundos.update(
      state.questaoAtual,
      (v) => v + decorrido,
      ifAbsent: () => decorrido,
    );
    _entrouNaQuestaoEm = DateTime.now();
  }

  /// Navega para a questão [index] — pra frente, pra trás, ou pulando
  /// direto (grade de questões). Registra o tempo gasto na questão que
  /// está sendo deixada antes de trocar.
  void irParaQuestao(int index) {
    if (index < 0 || index >= state.questoes.length) return;
    _registrarTempoQuestaoAtual();
    state = state.copyWith(questaoAtual: index);
  }

  void responder(String resposta) {
    final novasRespostas = Map<int, String>.from(state.respostas);
    novasRespostas[state.questaoAtual] = resposta;
    state = state.copyWith(respostas: novasRespostas);
  }

  Duration get tempoTotalDecorrido => _cronometroTotal.elapsed;

  Future<bool> finalizar() async {
    final accessToken = _ref.read(authProvider).accessToken;
    if (accessToken == null || state.attemptId == null) return false;

    _registrarTempoQuestaoAtual();
    _cronometroTotal.stop();

    state = state.copyWith(finalizando: true, errorMessage: null);
    try {
      final respostasPayload = [
        for (final entry in state.respostas.entries)
          {
            'question_id': state.questoes[entry.key].id,
            'resposta': entry.value,
            'tempo_segundos': _tempoPorQuestaoSegundos[entry.key] ?? 0,
          },
      ];

      final resultado = await _gameRepository.finishExam(
        accessToken,
        attemptId: state.attemptId!,
        respostas: respostasPayload,
        tempoTotalSegundos: _cronometroTotal.elapsed.inSeconds,
      );

      state = state.copyWith(
        finalizando: false,
        finalizada: true,
        resultado: resultado,
      );
      return true;
    } catch (e) {
      // DIAGNÓSTICO TEMPORÁRIO — remover depois de achar a causa raiz.
      debugPrint('[exam.finalizar] erro real: $e');
      // Retoma o cronômetro — o aluno pode tentar enviar de novo sem
      // perder o tempo já contado.
      _cronometroTotal.start();
      _entrouNaQuestaoEm = DateTime.now();
      state = state.copyWith(
        finalizando: false,
        errorMessage: 'Erro ao enviar a prova. Tente novamente.',
      );
      return false;
    }
  }

  /// Reseta o estado (ex: ao sair da tela sem finalizar, ou antes de
  /// começar uma nova tentativa).
  void limpar() {
    _cronometroTotal.stop();
    _tempoPorQuestaoSegundos.clear();
    _entrouNaQuestaoEm = null;
    state = ExamState();
  }
}

final examProvider = StateNotifierProvider<ExamNotifier, ExamState>((ref) {
  return ExamNotifier(GameRepository(), ref);
});

/// Histórico de tentativas de Prova por tópico. Usa `.family` (em vez de
/// um StateNotifier único) de propósito: o Mapa mostra vários
/// _TopicMetaPath ao mesmo tempo (um por tópico), cada um precisando
/// saber independentemente se aquele tópico específico já tem prova
/// concluída — um provider único compartilhado sobrescreveria o estado
/// de um tópico com o de outro.
final examAttemptsProvider =
    FutureProvider.family<List<ExamAttemptSummary>, String>((ref, topico) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return [];
  final repository = GameRepository();
  return repository.getExamAttempts(accessToken, topico: topico);
});
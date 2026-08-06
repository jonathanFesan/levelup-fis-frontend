// Arquivo: frontend/lib/data/models/exam_attempt_model.dart
// Modelos de dados da Prova — resultado de iniciar uma tentativa
// (attempt_id + questões) e resumo de uma tentativa (histórico/
// estatísticas, usado tanto na tela de estatísticas quanto no badge de
// "concluído" no nó da Prova no mapa).

import 'question_model.dart';

class ExamStartResult {
  final int attemptId;
  final List<QuestionModel> questoes;

  ExamStartResult({required this.attemptId, required this.questoes});

  factory ExamStartResult.fromJson(Map<String, dynamic> json) {
    final lista = (json['questoes'] as List)
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();
    return ExamStartResult(
      attemptId: json['attempt_id'] as int,
      questoes: lista,
    );
  }
}

class ExamAttemptSummary {
  final int id;
  final String topico;
  final String modo; // 'facil' | 'dificil'
  final DateTime iniciadoEm;
  final DateTime? finalizadoEm;
  final int? acertos;
  final int? erros;
  final int? tempoTotalSegundos;

  ExamAttemptSummary({
    required this.id,
    required this.topico,
    required this.modo,
    required this.iniciadoEm,
    this.finalizadoEm,
    this.acertos,
    this.erros,
    this.tempoTotalSegundos,
  });

  bool get finalizada => finalizadoEm != null;
  int get totalQuestoes => (acertos ?? 0) + (erros ?? 0);

  /// Estimativa de tempo médio por questão, em segundos. Null se ainda
  /// não houver dados suficientes.
  double? get tempoMedioPorQuestaoSegundos {
    if (tempoTotalSegundos == null || totalQuestoes == 0) return null;
    return tempoTotalSegundos! / totalQuestoes;
  }

  factory ExamAttemptSummary.fromJson(Map<String, dynamic> json) {
    return ExamAttemptSummary(
      id: json['id'] as int,
      topico: json['topico'] as String,
      modo: json['modo'] as String? ?? 'facil',
      iniciadoEm: DateTime.parse(json['iniciado_em'] as String),
      finalizadoEm: json['finalizado_em'] != null
          ? DateTime.parse(json['finalizado_em'] as String)
          : null,
      acertos: json['acertos'] as int?,
      erros: json['erros'] as int?,
      tempoTotalSegundos: json['tempo_total_segundos'] as int?,
    );
  }
}

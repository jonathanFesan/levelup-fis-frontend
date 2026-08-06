// Arquivo: frontend/lib/data/models/question_model.dart
// Modelo de dados de uma questão

class QuestionModel {
  final int id;
  final String topico;
  final String enunciado;
  final String tipo;
  final List<String>? opcoes;
  final int dificuldade;
  final int ordem;

  QuestionModel({
    required this.id,
    required this.topico,
    required this.enunciado,
    required this.tipo,
    this.opcoes,
    required this.dificuldade,
    required this.ordem,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    // O campo opcoes vem como List dinâmica do JSON
    List<String>? opcoesList;
    if (json['opcoes'] != null) {
      opcoesList = List<String>.from(json['opcoes']);
    }

    return QuestionModel(
      id: json['id'],
      topico: json['topico'] ?? '',
      enunciado: json['enunciado'] ?? '',
      tipo: json['tipo'] ?? 'multipla_escolha',
      opcoes: opcoesList,
      dificuldade: json['dificuldade'] ?? 1,
      ordem: json['ordem'] ?? 1,
    );
  }
}
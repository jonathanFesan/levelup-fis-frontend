// Arquivo: frontend/lib/data/models/curriculo_model.dart
// DTOs cruas do endpoint GET /curriculo/areas (ver backend/app/routes/
// curriculo.py e backend/sql/010_curriculo_dinamico.sql) — Áreas e Blocos
// do currículo, hoje editáveis pelo painel em vez de hardcoded no app.
//
// Não confundir com ModuloInfo/TopicoInfo (domain/models/curriculum.dart):
// estes aqui são o formato bruto que chega da API; os outros são o formato
// que o resto do app (telas) já conhece e consome, incluindo os blocos de
// pré-visualização (mockExercicios) que continuam hardcoded — a conversão
// entre os dois fica em domain/providers/curriculo_provider.dart.

class BlocoModel {
  final String id;
  final String areaId;
  final String titulo;
  final int ordem;
  final int nivelMinimo;

  BlocoModel({
    required this.id,
    required this.areaId,
    required this.titulo,
    required this.ordem,
    required this.nivelMinimo,
  });

  factory BlocoModel.fromJson(Map<String, dynamic> json) {
    return BlocoModel(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      titulo: json['titulo'] as String,
      ordem: json['ordem'] as int? ?? 0,
      nivelMinimo: json['nivel_minimo'] as int? ?? 1,
    );
  }
}

class AreaModel {
  final String id;
  final String titulo;

  /// Emoji (ex: '⚙️'), não IconData — ver decisão em
  /// sql/010_curriculo_dinamico.sql.
  final String icone;
  final int ordem;
  final List<BlocoModel> blocos;

  AreaModel({
    required this.id,
    required this.titulo,
    required this.icone,
    required this.ordem,
    required this.blocos,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    final blocosJson = json['blocos'] as List<dynamic>? ?? [];
    final blocos = blocosJson
        .map((b) => BlocoModel.fromJson(b as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    return AreaModel(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      icone: json['icone'] as String? ?? '',
      ordem: json['ordem'] as int? ?? 0,
      blocos: blocos,
    );
  }
}

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

/// Conteúdo flexível de um Capítulo tipo 'curiosidade' — texto, PDF,
/// imagem e vídeo, todos opcionais e combináveis (ver
/// backend/sql/011_capitulos_livres.sql, tabela capitulo_conteudo).
class CapituloConteudoModel {
  final String? texto;
  final String? pdfUrl;
  final String? imagemUrl;
  final String? videoUrl;

  const CapituloConteudoModel({
    this.texto,
    this.pdfUrl,
    this.imagemUrl,
    this.videoUrl,
  });

  factory CapituloConteudoModel.fromJson(Map<String, dynamic> json) {
    return CapituloConteudoModel(
      texto: json['texto'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      imagemUrl: json['imagem_url'] as String?,
      videoUrl: json['video_url'] as String?,
    );
  }

  bool get vazio =>
      (texto == null || texto!.trim().isEmpty) &&
      (pdfUrl == null || pdfUrl!.trim().isEmpty) &&
      (imagemUrl == null || imagemUrl!.trim().isEmpty) &&
      (videoUrl == null || videoUrl!.trim().isEmpty);
}

/// Capítulo dentro de um Bloco — Resumo/Fixação/Exercícios/Prova/
/// Curiosidade, livremente criados/reordenados pelo painel (ver
/// backend/sql/011_capitulos_livres.sql).
///
/// `tipo` é um dos valores crus do banco: 'resumo', 'fixacao', 'extra',
/// 'prova' ou 'curiosidade' — mesmos usados como `categoria` em
/// questions, pra Fixação/Exercícios/Prova.
class CapituloModel {
  final int id;
  final String blocoId;
  final String titulo;
  final String tipo;
  final int ordem;
  final bool obrigatorio;

  /// Só preenchido pra Capítulos tipo 'curiosidade' — o backend já
  /// embute o conteúdo na mesma resposta (ver curriculo.py).
  final CapituloConteudoModel? conteudo;

  const CapituloModel({
    required this.id,
    required this.blocoId,
    required this.titulo,
    required this.tipo,
    required this.ordem,
    required this.obrigatorio,
    this.conteudo,
  });

  factory CapituloModel.fromJson(Map<String, dynamic> json) {
    final conteudoJson = json['conteudo'] as Map<String, dynamic>?;
    return CapituloModel(
      id: json['id'] as int,
      blocoId: json['bloco_id'] as String,
      titulo: json['titulo'] as String,
      tipo: json['tipo'] as String? ?? 'curiosidade',
      ordem: json['ordem'] as int? ?? 0,
      obrigatorio: json['obrigatorio'] as bool? ?? false,
      conteudo: conteudoJson != null
          ? CapituloConteudoModel.fromJson(conteudoJson)
          : null,
    );
  }
}

class BlocoModel {
  final String id;
  final String areaId;
  final String titulo;
  final int ordem;
  final int nivelMinimo;
  final List<CapituloModel> capitulos;

  BlocoModel({
    required this.id,
    required this.areaId,
    required this.titulo,
    required this.ordem,
    required this.nivelMinimo,
    this.capitulos = const [],
  });

  factory BlocoModel.fromJson(Map<String, dynamic> json) {
    final capitulosJson = json['capitulos'] as List<dynamic>? ?? [];
    final capitulos = capitulosJson
        .map((c) => CapituloModel.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

    return BlocoModel(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      titulo: json['titulo'] as String,
      ordem: json['ordem'] as int? ?? 0,
      nivelMinimo: json['nivel_minimo'] as int? ?? 1,
      capitulos: capitulos,
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

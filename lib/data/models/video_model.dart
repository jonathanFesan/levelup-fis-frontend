// Arquivo: frontend/lib/data/models/video_model.dart
// Modelo de vídeo — "curtas do cotidiano" e aulas completas.
//
// Espelha o retorno de GET /videos/ no backend (app/routes/videos.py),
// que já vem com os campos calculados 'desbloqueado' e 'assistido' pro
// usuário logado — não precisa (nem deve) ser recalculado no Flutter.

class VideoModel {
  final int id;
  final String titulo;
  final String? descricao;
  final String urlVideo;
  final String? thumbnailUrl;
  final int duracaoSegundos;
  final String topico;
  final String tipoVideo; // 'curta_cotidiano' ou 'aula_completa'
  final int? nivelDesbloqueio;
  final int ordem;
  final bool desbloqueado;
  final bool assistido;

  VideoModel({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.urlVideo,
    this.thumbnailUrl,
    required this.duracaoSegundos,
    required this.topico,
    required this.tipoVideo,
    this.nivelDesbloqueio,
    required this.ordem,
    required this.desbloqueado,
    required this.assistido,
  });

  bool get isCurta => tipoVideo == 'curta_cotidiano';

  VideoModel copyWith({bool? assistido}) {
    return VideoModel(
      id: id,
      titulo: titulo,
      descricao: descricao,
      urlVideo: urlVideo,
      thumbnailUrl: thumbnailUrl,
      duracaoSegundos: duracaoSegundos,
      topico: topico,
      tipoVideo: tipoVideo,
      nivelDesbloqueio: nivelDesbloqueio,
      ordem: ordem,
      desbloqueado: desbloqueado,
      assistido: assistido ?? this.assistido,
    );
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as int,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      urlVideo: json['url_video'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duracaoSegundos: json['duracao_segundos'] as int? ?? 0,
      topico: json['topico'] as String,
      tipoVideo: json['tipo_video'] as String,
      nivelDesbloqueio: json['nivel_desbloqueio'] as int?,
      ordem: json['ordem'] as int? ?? 1,
      desbloqueado: json['desbloqueado'] as bool? ?? true,
      assistido: json['assistido'] as bool? ?? false,
    );
  }
}

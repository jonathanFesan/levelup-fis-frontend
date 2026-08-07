// Arquivo: frontend/lib/domain/providers/topic_content_provider.dart
// Conteúdo editorial por tópico (hoje: texto do Resumo), mantido pelo
// painel administrativo — ver backend/app/routes/topic_content.py.
//
// Mesmo padrão de topicProgressProvider (topic_progress_provider.dart):
// .family porque cada tela de Resumo pede o conteúdo do seu próprio
// tópico, com cache independente por topico.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

/// Conteúdo editorial de um tópico, mantido pelo painel administrativo:
/// texto do Resumo e nível mínimo pra desbloquear o tópico (ver
/// sql/008_nivel_minimo_editavel.sql).
class TopicContentState {
  final String? resumoTexto;

  /// Nível global mínimo definido pelo admin no painel. Null se o
  /// admin nunca configurou isso pra esse tópico — nesse caso, quem
  /// consome este provider deve cair pro valor padrão do próprio app
  /// (TopicoInfo.nivelMinimo em curriculum.dart), nunca tratar null
  /// como "sem trava nenhuma".
  final int? nivelMinimo;

  TopicContentState({this.resumoTexto, this.nivelMinimo});
}

/// `resumoTexto` vem null se o admin ainda não salvou nada pra esse
/// tópico no painel — a tela trata isso mostrando um aviso, não um erro.
final topicContentProvider =
    FutureProvider.family<TopicContentState, String>((ref, topico) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return TopicContentState();
  final repository = GameRepository();
  final json = await repository.getTopicContent(accessToken, topico: topico);
  return TopicContentState(
    resumoTexto: json['resumo_texto'] as String?,
    nivelMinimo: json['nivel_minimo'] as int?,
  );
});

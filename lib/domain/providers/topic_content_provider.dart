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

/// `resumoTexto` vem null se o admin ainda não salvou nada pra esse
/// tópico no painel — a tela trata isso mostrando um aviso, não um erro.
final topicContentProvider =
    FutureProvider.family<String?, String>((ref, topico) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return null;
  final repository = GameRepository();
  final json = await repository.getTopicContent(accessToken, topico: topico);
  return json['resumo_texto'] as String?;
});

// Arquivo: frontend/lib/domain/providers/capitulo_progress_provider.dart
// Estado de progresso por Capítulo (hoje só usado por Capítulos tipo
// 'curiosidade' — Resumo/Fixação continuam em topic_progress_provider.dart,
// que já existia). Ver backend/app/routes/capitulo_progress.py e
// sql/012_capitulo_progress.sql.
//
// Mesmo padrão de topicProgressProvider: `.family` por `topico` (bloco
// id) porque o Mapa mostra vários tópicos ao mesmo tempo. Diferente
// dele, devolve um mapa {capituloId: concluido} em vez de um estado
// fixo, já que um Bloco pode ter qualquer quantidade de Capítulos
// 'curiosidade'.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

final capituloProgressProvider =
    FutureProvider.family<Map<int, bool>, String>((ref, topico) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return {};
  final repository = GameRepository();
  final json = await repository.getCapituloProgress(accessToken, topico: topico);
  return json.map((key, value) => MapEntry(int.parse(key), value as bool));
});

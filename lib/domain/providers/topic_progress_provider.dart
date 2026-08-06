// Arquivo: frontend/lib/domain/providers/topic_progress_provider.dart
// Estado de progresso por tópico (Resumo lido / Fixação concluída) —
// os dois marcos que travam bônus únicos e decidem o desbloqueio do
// próximo capítulo (ver backend/app/routes/topic_progress.py e a
// reescrita de POST /questions/answer em questions.py).
//
// Mesmo padrão de examAttemptsProvider (exam_provider.dart): usa
// `.family` porque o mapa mostra vários tópicos ao mesmo tempo, cada um
// precisando saber seu próprio estado independentemente.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/models/curriculum.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

class TopicProgressState {
  final bool resumoConcluido;
  final bool fixacaoConcluida;

  TopicProgressState({
    this.resumoConcluido = false,
    this.fixacaoConcluida = false,
  });

  factory TopicProgressState.fromJson(Map<String, dynamic> json) {
    return TopicProgressState(
      resumoConcluido: json['resumo_concluido'] ?? false,
      fixacaoConcluida: json['fixacao_concluida'] ?? false,
    );
  }
}

final topicProgressProvider =
    FutureProvider.family<TopicProgressState, String>((ref, topico) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return TopicProgressState();
  final repository = GameRepository();
  final json = await repository.getTopicProgress(accessToken, topico: topico);
  return TopicProgressState.fromJson(json);
});

/// Se um tópico ("capítulo") está desbloqueado pra navegação — chave é
/// `topico.id` (String), não o objeto TopicoInfo, pro cache do
/// `.family` funcionar de forma óbvia (mesmo padrão dos outros
/// providers desta família).
///
/// Regra: "capítulo" = cada TopicoInfo dentro de um ModuloInfo, na
/// ordem em que aparecem em kCurriculo. Só tópicos com `implementado:
/// true` (conteúdo real) entram na sequência de desbloqueio — o
/// primeiro deles no módulo é sempre livre; os seguintes exigem que o
/// anterior já tenha `fixacao_concluida == true`.
///
/// Tópicos que só têm `mockExercicios` (sem `implementado`) FICAM DE
/// FORA dessa trava de propósito — são a ferramenta de teste de UI
/// descrita em curriculum.dart ("SÓ PARA TESTE de navegação"), não
/// fazem parte da progressão real ainda. Travar eles removeria essa
/// ferramenta sem ter sido pedido.
final topicoDesbloqueadoProvider =
    FutureProvider.family<bool, String>((ref, topicoId) async {
  TopicoInfo? topico;
  ModuloInfo? moduloDono;

  for (final modulo in kCurriculo) {
    for (final t in modulo.topicos) {
      if (t.id == topicoId) {
        topico = t;
        moduloDono = modulo;
        break;
      }
    }
    if (topico != null) break;
  }

  if (topico == null || moduloDono == null) return true;

  if (!topico.implementado) {
    return topico.navegavel;
  }

  final implementados =
      moduloDono.topicos.where((t) => t.implementado).toList();
  final index = implementados.indexWhere((t) => t.id == topicoId);
  if (index <= 0) return true; // primeiro capítulo real do módulo

  final anterior = implementados[index - 1];
  final progressoAnterior =
      await ref.watch(topicProgressProvider(anterior.id).future);
  return progressoAnterior.fixacaoConcluida;
});


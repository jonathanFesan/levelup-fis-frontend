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
import 'package:levelup_fis/domain/providers/curriculo_provider.dart';
import 'package:levelup_fis/domain/providers/topic_content_provider.dart';
import 'package:levelup_fis/domain/providers/user_provider.dart';

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
/// REGRA ATUAL (confirmada com o responsável do produto — refinamento
/// pré-testes reais): as DUAS condições precisam valer ao mesmo tempo
/// para um tópico "capítulo" (implementado: true) abrir:
///   1. Nível mínimo: profiles.nivel do aluno >= nível mínimo do tópico
///      (topic_content.nivel_minimo, configurável pelo painel; se o
///      admin nunca definiu isso, cai pro padrão fixo em
///      TopicoInfo.nivelMinimo — ver curriculum.dart).
///   2. Sequência: o tópico anterior do mesmo módulo (na ordem vinda de
///      curriculoProvider, só contando os já implementados) precisa ter
///      `fixacao_concluida == true`.
/// O primeiro capítulo implementado do módulo só precisa da condição 1
/// (não há "anterior" pra exigir sequência).
///
/// Tópicos que só têm `mockExercicios` (sem `implementado`) são
/// ferramenta de teste de UI, sem conteúdo real por trás (ver
/// curriculum.dart) — ficam bloqueados como "Em breve" para qualquer
/// aluno normal. Só a conta admin (profiles.is_admin) os vê navegáveis,
/// para continuar podendo testar o fluxo de navegação.
final topicoDesbloqueadoProvider =
    FutureProvider.family<bool, String>((ref, topicoId) async {
  TopicoInfo? topico;
  ModuloInfo? moduloDono;

  final curriculo = await ref.watch(curriculoProvider.future);
  for (final modulo in curriculo) {
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

  final isAdmin = ref.watch(userProvider).user?.isAdmin ?? false;

  // Tópico sem conteúdo real (só modo de teste, ou nem isso): fora do
  // fluxo de progressão de verdade. Só o admin pode navegar, pra testar
  // a UI antes do conteúdo real existir.
  if (!topico.implementado) {
    return isAdmin && topico.navegavel;
  }

  if (isAdmin) return true; // admin não fica travado em nada

  final nivelAtual = ref.watch(userProvider).user?.nivel ?? 1;

  // Nível mínimo: prioriza o que o admin configurou no painel
  // (topic_content.nivel_minimo); se ele nunca mexeu nisso pra esse
  // tópico, cai pro valor padrão fixo em curriculum.dart — nunca fica
  // sem nenhuma trava por causa disso.
  final conteudo =
      await ref.watch(topicContentProvider(topicoId).future);
  final nivelMinimo = conteudo.nivelMinimo ?? topico.nivelMinimo;
  if (nivelAtual < nivelMinimo) return false;

  final implementados =
      moduloDono.topicos.where((t) => t.implementado).toList();
  final index = implementados.indexWhere((t) => t.id == topicoId);
  if (index <= 0) return true; // primeiro capítulo real do módulo (só nível)

  final anterior = implementados[index - 1];
  final progressoAnterior =
      await ref.watch(topicProgressProvider(anterior.id).future);
  return progressoAnterior.fixacaoConcluida;
});


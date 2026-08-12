// Arquivo: frontend/lib/domain/providers/game_path_provider.dart
// Gerencia a trilha de aprendizado e o progresso no mapa
//
// Atualizado nesta sessão: GamePathNotifier passou a receber um Ref (igual
// ao UserNotifier) para ler authProvider.accessToken e repassar para
// GameRepository.getQuestions(), já que /questions/ agora exige o header
// Authorization. Sem isso, o RLS bloqueava a query silenciosamente e a
// trilha do mapa vinha sempre vazia.
//
// Atualizado de novo agora: loadGamePath() passou a receber um parâmetro
// `topico` (padrão 'cinematica', para não quebrar chamadas existentes) e
// repassá-lo para GameRepository.getQuestions() — que já aceitava esse
// parâmetro, só não era usado. Antes disso, era impossível carregar a
// trilha de qualquer tópico que não fosse Cinemática: mesmo passando
// dados diferentes, a busca sempre vinha fixa em 'cinematica'.
//
// Atualizado mais uma vez: loadGamePath() agora também recebe `categoria`
// ('fixacao', 'extra' ou 'prova'), repassado junto com `topico`. É isso
// que permite carregar trilhas separadas para Fixação, Exercícios
// (caminho opcional) e Prova final dentro do mesmo tópico.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/models/question_model.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

// Representa um nó (fase) do mapa gamificado
class MapNode {
  final int ordem;
  final String titulo;
  final QuestionModel question;
  final bool desbloqueado;
  final bool concluido;

  MapNode({
    required this.ordem,
    required this.titulo,
    required this.question,
    required this.desbloqueado,
    required this.concluido,
  });

  MapNode copyWith({
    bool? desbloqueado,
    bool? concluido,
  }) {
    return MapNode(
      ordem: ordem,
      titulo: titulo,
      question: question,
      desbloqueado: desbloqueado ?? this.desbloqueado,
      concluido: concluido ?? this.concluido,
    );
  }
}

// Estado do mapa
class GamePathState {
  final bool isLoading;
  final List<MapNode> nodes;
  final int currentNodeIndex;
  final String? errorMessage;

  /// Tópico e categoria que geraram os [nodes] atuais. Usado por
  /// [GamePathNotifier.loadGamePath] para decidir se pode reaproveitar o
  /// estado em memória (com o progresso feito nesta sessão) em vez de
  /// buscar tudo de novo na API — o que resetaria `concluido`/
  /// `desbloqueado` de todos os nós, apagando o progresso local.
  final String? loadedTopico;
  final String? loadedCategoria;

  GamePathState({
    this.isLoading = false,
    this.nodes = const [],
    this.currentNodeIndex = 0,
    this.errorMessage,
    this.loadedTopico,
    this.loadedCategoria,
  });

  GamePathState copyWith({
    bool? isLoading,
    List<MapNode>? nodes,
    int? currentNodeIndex,
    String? errorMessage,
    String? loadedTopico,
    String? loadedCategoria,
  }) {
    return GamePathState(
      isLoading: isLoading ?? this.isLoading,
      nodes: nodes ?? this.nodes,
      currentNodeIndex: currentNodeIndex ?? this.currentNodeIndex,
      errorMessage: errorMessage,
      loadedTopico: loadedTopico ?? this.loadedTopico,
      loadedCategoria: loadedCategoria ?? this.loadedCategoria,
    );
  }
}

class GamePathNotifier extends StateNotifier<GamePathState> {
  final GameRepository _gameRepository;
  final Ref _ref;

  GamePathNotifier(this._gameRepository, this._ref) : super(GamePathState());

  /// Carrega as questões e monta os nós do mapa para o [topico] e
  /// [categoria] informados ('fixacao', 'extra' ou 'prova').
  ///
  /// Mantém 'cinematica'/'fixacao' como padrão só por compatibilidade com
  /// qualquer chamada antiga que ainda não tenha sido atualizada — todo
  /// código novo deve sempre passar os dois explicitamente.
  ///
  /// IMPORTANTE: se o [topico]+[categoria] pedidos já são os mesmos que
  /// geraram os nós atuais (`state.loadedTopico`/`loadedCategoria`), a
  /// busca é PULADA por padrão — evita um round-trip desnecessário à API
  /// toda vez que o aluno volta pra mesma trilha na mesma sessão (ex:
  /// Mapa → Tópico → Fixação de novo). O backend já persiste
  /// `concluido`/`desbloqueado` de verdade (via user_progress, ver
  /// respondidaCorretamente em question_model.dart), então mesmo um
  /// reload completo reconstrói a trilha certa — mas pular a busca
  /// quando nada mudou continua sendo mais rápido. Use [forceReload]
  /// quando realmente precisar buscar de novo (ex: botão "Tentar
  /// novamente" após erro, ou ao trocar de tópico/categoria — isso já é
  /// detectado automaticamente).
  Future<void> loadGamePath({
    String topico = 'cinematica',
    String categoria = 'fixacao',
    bool forceReload = false,
  }) async {
    final jaCarregado = state.loadedTopico == topico &&
        state.loadedCategoria == categoria &&
        state.nodes.isNotEmpty;
    if (jaCarregado && !forceReload) return;

    final accessToken = _ref.read(authProvider).accessToken;
    if (accessToken == null) {
      state = state.copyWith(
        errorMessage: 'Sessão expirada. Faça login novamente.',
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final questions = await _gameRepository.getQuestions(
        accessToken,
        topico: topico,
        categoria: categoria,
      );

      // Converte questões em nós do mapa.
      //
      // BUG CRÍTICO CORRIGIDO: antes, todo nó nascia com concluido=false
      // e só o primeiro desbloqueado=true, não importa o que o aluno já
      // tivesse feito antes — isso apagava visualmente o progresso de
      // quem já tinha respondido certo sempre que a trilha precisava
      // ser buscada de novo (app reaberto do zero, processo morto em
      // segundo plano, forceReload). Agora usa
      // question.respondidaCorretamente (que já vem persistido do
      // backend, cruzando com user_progress) pra marcar `concluido` de
      // verdade, e desbloqueia cada nó cujo anterior já foi concluído
      // — não só o primeiro da lista.
      final nodes = questions.asMap().entries.map((entry) {
        final index = entry.key;
        final question = entry.value;
        final concluido = question.respondidaCorretamente;
        final desbloqueado = index == 0 ||
            questions[index - 1].respondidaCorretamente ||
            concluido;
        return MapNode(
          ordem: index + 1,
          titulo: 'Fase ${index + 1}',
          question: question,
          desbloqueado: desbloqueado,
          concluido: concluido,
        );
      }).toList();

      // currentNodeIndex começa no primeiro nó ainda não concluído (ou
      // no último, se tudo já foi respondido certo) — assim quem volta
      // pra uma trilha já em andamento continua de onde parou, em vez
      // de sempre cair no início.
      final primeiroNaoConcluido = nodes.indexWhere((n) => !n.concluido);
      final currentNodeIndex =
          primeiroNaoConcluido == -1 ? nodes.length - 1 : primeiroNaoConcluido;

      state = state.copyWith(
        isLoading: false,
        nodes: nodes,
        currentNodeIndex: currentNodeIndex,
        loadedTopico: topico,
        loadedCategoria: categoria,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar o mapa.',
      );
    }
  }

  /// Marca um nó como concluído e desbloqueia o próximo
  void completeNode(int nodeIndex) {
    final updatedNodes = [...state.nodes];

    // Marca o nó atual como concluído
    updatedNodes[nodeIndex] = updatedNodes[nodeIndex].copyWith(concluido: true);

    // Desbloqueia o próximo nó (se existir)
    if (nodeIndex + 1 < updatedNodes.length) {
      updatedNodes[nodeIndex + 1] =
          updatedNodes[nodeIndex + 1].copyWith(desbloqueado: true);
    }

    state = state.copyWith(
      nodes: updatedNodes,
      currentNodeIndex: nodeIndex + 1,
    );
  }
}

final gamePathProvider =
    StateNotifierProvider<GamePathNotifier, GamePathState>((ref) {
  return GamePathNotifier(GameRepository(), ref);
});
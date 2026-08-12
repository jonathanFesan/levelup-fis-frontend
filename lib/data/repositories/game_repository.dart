// Arquivo: frontend/lib/data/repositories/game_repository.dart
// Chamadas HTTP para questões e perfil
//
// Atualizado nesta sessão: todos os métodos agora recebem o accessToken
// do usuário logado e mandam o header "Authorization: Bearer <token>".
// Sem isso, o backend não consegue autenticar a query no Supabase e o
// RLS bloqueia (silenciosamente, no caso de listas, ou com 404, no caso
// de .single()). Quem chama esses métodos (providers/telas) precisa
// passar o token, normalmente lido de authProvider.accessToken.
//
// Atualizado de novo agora: getQuestions() passou a aceitar também
// `categoria` ('fixacao', 'extra' ou 'prova'), repassado como query
// param pro backend — é isso que separa as perguntas de Fixação, do
// caminho opcional de Exercícios e da Prova final dentro do mesmo tópico.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:levelup_fis/core/constants/app_constants.dart';
import 'package:levelup_fis/data/models/question_model.dart';
import 'package:levelup_fis/data/models/progress_model.dart';
import 'package:levelup_fis/data/models/exam_attempt_model.dart';
import 'package:levelup_fis/data/models/user_model.dart';
import 'package:levelup_fis/data/models/video_model.dart';
import 'package:levelup_fis/data/models/curriculo_model.dart';

class GameRepository {
  final String baseUrl = AppConstants.baseUrl;

  Map<String, String> _authHeaders(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  /// Busca as questões de um tópico e categoria.
  ///
  /// `categoria` separa as perguntas dentro do mesmo tópico: 'fixacao'
  /// (padrão), 'extra' (caminho opcional) ou 'prova' (prova final).
  Future<List<QuestionModel>> getQuestions(
    String accessToken, {
    String topico = 'cinematica',
    String categoria = 'fixacao',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/questions/?topico=$topico&categoria=$categoria'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((q) => QuestionModel.fromJson(q)).toList();
    } else {
      throw Exception('Erro ao buscar questões.');
    }
  }

  /// Envia a resposta do aluno e recebe o resultado
  Future<AnswerResultModel> answerQuestion(
    int questionId,
    String resposta,
    String accessToken,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/questions/answer'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'question_id': questionId,
        'resposta': resposta,
      }),
    );

    if (response.statusCode == 200) {
      return AnswerResultModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erro ao enviar resposta.');
    }
  }

  /// Busca o perfil do usuário
  Future<UserModel> getProfile(String userId, String accessToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile/$userId'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      // DIAGNÓSTICO TEMPORÁRIO — inclui status e corpo da resposta.
      throw Exception(
        'Erro ao buscar perfil. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Debita 1 Carga (vidas) — o backend recalcula a recarga automática
  /// antes de aplicar, então o perfil devolvido já reflete qualquer
  /// carga que tenha recarregado sozinha desde a última checagem.
  Future<UserModel> loseCharge(String userId, String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/$userId/lose-charge'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Erro ao debitar carga. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Compra 1 Carga de emergência por Fótons (custo definido no
  /// backend — hoje 20). Lança exceção com a mensagem do servidor se
  /// não puder (Cargas já cheias ou Fótons insuficientes).
  Future<UserModel> buyCharge(String userId, String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/$userId/buy-charge'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Erro ao comprar carga.');
    }
  }

  /// Cria o perfil após o cadastro.
  ///
  /// BUG CORRIGIDO: esta chamada nunca checava `response.statusCode` —
  /// se a criação falhasse no backend (RLS bloqueando o INSERT, erro de
  /// rede, etc.), o cadastro seguia em frente como se tivesse dado
  /// certo: sessão salva, usuário "logado", mas SEM NENHUMA linha em
  /// `profiles`. O app então quebrava silenciosamente em cascata (perfil
  /// não carrega, nível cai pro padrão 1, tópicos com nível mínimo maior
  /// ficam travados) sem nenhum erro visível na hora do cadastro, que é
  /// quando dava pra avisar e pra tentar de novo. Também passa a
  /// escapar `userId`/`email` na URL — sem isso, um e-mail com "+"
  /// (comum, ex: "nome+teste@gmail.com") virava espaço no query string.
  Future<void> createProfile(
    String userId,
    String email,
    String accessToken,
  ) async {
    final uri = Uri.parse('$baseUrl/profile/create').replace(
      queryParameters: {'user_id': userId, 'email': email},
    );
    final response = await http.post(uri, headers: _authHeaders(accessToken));

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao criar perfil. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Atualiza XP e moedas após acerto
  Future<void> updateProfile(
    String userId,
    String accessToken, {
    int? xp,
    int? moedas,
    int? vidas,
    String? nome,
  }) async {
    final body = <String, dynamic>{};
    if (xp != null) body['xp'] = xp;
    if (moedas != null) body['moedas'] = moedas;
    if (vidas != null) body['vidas'] = vidas;
    if (nome != null) body['nome'] = nome;

    await http.patch(
      Uri.parse('$baseUrl/profile/$userId'),
      headers: _authHeaders(accessToken),
      body: jsonEncode(body),
    );
  }

  /// Busca os vídeos ("curtas do cotidiano" e aulas completas),
  /// opcionalmente filtrados por [topico] e/ou [tipoVideo]
  /// ('curta_cotidiano' ou 'aula_completa'). Cada vídeo já vem do
  /// backend com 'desbloqueado' e 'assistido' calculados para o usuário
  /// logado (ver app/routes/videos.py).
  Future<List<VideoModel>> getVideos(
    String accessToken, {
    String? topico,
    String? tipoVideo,
  }) async {
    final params = <String, String>{
      if (topico != null) 'topico': topico,
      if (tipoVideo != null) 'tipo_video': tipoVideo,
    };
    final uri = Uri.parse('$baseUrl/videos/')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(uri, headers: _authHeaders(accessToken));

    if (response.statusCode == 200) {
      // DIAGNÓSTICO TEMPORÁRIO — mostra exatamente o que o backend
      // devolveu, pra descobrir se o problema dos vídeos antigos é no
      // servidor ou no app. debugPrint (não print) porque o Android
      // corta linhas muito longas no logcat. Remover depois de
      // identificar a causa.
      debugPrint(
        '[DEBUG getVideos] uri=$uri status=${response.statusCode} '
        'body=${response.body}',
      );
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((v) => VideoModel.fromJson(v)).toList();
    } else {
      // DIAGNÓSTICO TEMPORÁRIO — inclui status e corpo da resposta.
      throw Exception(
        'Erro ao buscar vídeos. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Marca um vídeo como assistido pelo usuário logado.
  Future<void> markVideoWatched(String accessToken, int videoId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/videos/$videoId/watch'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao marcar vídeo como assistido.');
    }
  }

  /// Inicia uma nova tentativa de Prova para [topico], no [modo] 'facil'
  /// ou 'dificil'. Devolve o attemptId e a lista de questões (sem
  /// gabarito — a correção só acontece em finishExam()).
  Future<ExamStartResult> startExam(
    String accessToken, {
    required String topico,
    required String modo,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/exam/start'),
          headers: _authHeaders(accessToken),
          body: jsonEncode({'topico': topico, 'modo': modo}),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Tempo esgotado tentando baixar a prova. Confira sua conexão.',
          ),
        );

    if (response.statusCode == 200) {
      return ExamStartResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Erro ao iniciar prova. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Envia todas as respostas de uma tentativa pra correção no backend.
  /// [respostas] é uma lista de mapas
  /// {'question_id': int, 'resposta': String, 'tempo_segundos': int}.
  Future<Map<String, dynamic>> finishExam(
    String accessToken, {
    required int attemptId,
    required List<Map<String, dynamic>> respostas,
    required int tempoTotalSegundos,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/exam/$attemptId/finish'),
          headers: _authHeaders(accessToken),
          body: jsonEncode({
            'respostas': respostas,
            'tempo_total_segundos': tempoTotalSegundos,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Tempo esgotado tentando enviar a prova. Confira sua conexão.',
          ),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erro ao finalizar prova. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Histórico de tentativas de Prova do usuário logado para [topico].
  Future<List<ExamAttemptSummary>> getExamAttempts(
    String accessToken, {
    required String topico,
  }) async {
    final uri = Uri.parse('$baseUrl/exam/attempts')
        .replace(queryParameters: {'topico': topico});
    final response = await http.get(uri, headers: _authHeaders(accessToken));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((a) => ExamAttemptSummary.fromJson(a)).toList();
    } else {
      throw Exception(
        'Erro ao buscar histórico da prova. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Estado de progresso do tópico (Resumo lido / Fixação concluída).
  Future<Map<String, dynamic>> getTopicProgress(
    String accessToken, {
    required String topico,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/topic-progress/$topico'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erro ao buscar progresso do tópico. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Marca o Resumo de [topico] como lido — idempotente no backend
  /// (só paga o bônus de +10 J na primeira vez).
  Future<Map<String, dynamic>> marcarResumoConcluido(
    String accessToken, {
    required String topico,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/topic-progress/$topico/resumo'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erro ao marcar resumo como concluído. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Progresso do usuário nos Capítulos de [topico] — mapa
  /// {capitulo_id: concluido}, hoje só relevante pra Capítulos tipo
  /// 'curiosidade' (ver sql/012_capitulo_progress.sql).
  Future<Map<String, dynamic>> getCapituloProgress(
    String accessToken, {
    required String topico,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/capitulo-progress/$topico'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erro ao buscar progresso de capítulos. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Marca um Capítulo (hoje: só 'curiosidade') como concluído — é isso
  /// que libera o próximo passo da sequência no Mapa.
  Future<void> concluirCapitulo(
    String accessToken, {
    required int capituloId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/capitulo-progress/$capituloId/concluir'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao concluir capítulo. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Currículo dinâmico (Fase 1): Áreas com seus Blocos aninhados, na
  /// ordem definida pelo painel (ver sql/010_curriculo_dinamico.sql e
  /// app/routes/curriculo.py). Substitui o kCurriculo hardcoded que
  /// existia antes em curriculum.dart.
  Future<List<AreaModel>> getCurriculo(String accessToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/curriculo/areas'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((a) => AreaModel.fromJson(a)).toList();
    } else {
      throw Exception(
        'Erro ao buscar currículo. status=${response.statusCode} body=${response.body}',
      );
    }
  }

  /// Conteúdo editorial do tópico (hoje: só o texto do Resumo),
  /// mantido pelo painel administrativo (topic_content, via Supabase
  /// REST direto — este endpoint só lê). Se o admin ainda não salvou
  /// nada pra esse tópico, `resumo_texto` vem null.
  Future<Map<String, dynamic>> getTopicContent(
    String accessToken, {
    required String topico,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/topic-content/$topico'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Erro ao buscar conteúdo do tópico. status=${response.statusCode} body=${response.body}',
      );
    }
  }
}
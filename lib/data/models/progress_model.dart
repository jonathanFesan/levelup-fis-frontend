// Arquivo: frontend/lib/data/models/progress_model.dart
// Modelo de resposta após o aluno responder uma questão
//
// Atualizado nesta sessão (Progresso de Trilha): POST /questions/answer
// deixou de ser stateless — agora aplica a recompensa direto no perfil
// no backend (retry pela metade, bônus de conclusão da Fixação, etc.)
// e devolve os TOTAIS atualizados, não só o ganho desta resposta. O
// Flutter passa a REFLETIR esses totais (ver
// user_provider.dart.atualizarTotais) em vez de somar xpGanho/
// moedasGanhas por conta própria — só o backend sabe a conta certa
// agora.

class AnswerResultModel {
  final bool acertou;
  final String respostaCorreta;
  final String? explicacao;

  /// Ganho NESTA resposta especificamente — pode ser 0 mesmo com
  /// acertou=true (questão já tinha sido paga antes) ou metade do
  /// valor cheio (retry depois de errar — ver PISO_JOULES_RETRY no
  /// backend). Usado só pra mostrar "+X J" na tela de Resultado.
  final int xpGanho;
  final int moedasGanhas;

  /// Bônus único de completar toda a Fixação obrigatória do tópico
  /// (0 se não completou agora). Quando > 0, [capituloDesbloqueado]
  /// também vem true.
  final int bonusCapituloGanho;
  final bool capituloDesbloqueado;

  /// Totais JÁ ATUALIZADOS do perfil, direto da resposta do backend —
  /// é o que user_provider.dart usa pra setar o estado local (nunca
  /// soma xpGanho a um valor antigo).
  final int joulesTotais;
  final int fotonsTotais;
  final int nivelAtual;

  AnswerResultModel({
    required this.acertou,
    required this.respostaCorreta,
    this.explicacao,
    required this.xpGanho,
    required this.moedasGanhas,
    this.bonusCapituloGanho = 0,
    this.capituloDesbloqueado = false,
    required this.joulesTotais,
    required this.fotonsTotais,
    required this.nivelAtual,
  });

  factory AnswerResultModel.fromJson(Map<String, dynamic> json) {
    return AnswerResultModel(
      acertou: json['acertou'] ?? false,
      respostaCorreta: json['resposta_correta'] ?? '',
      explicacao: json['explicacao'],
      xpGanho: json['xp_ganho'] ?? 0,
      moedasGanhas: json['moedas_ganhas'] ?? 0,
      bonusCapituloGanho: json['bonus_capitulo_ganho'] ?? 0,
      capituloDesbloqueado: json['capitulo_desbloqueado'] ?? false,
      // joules_totais/fotons_totais/nivel_atual são obrigatórios na
      // resposta nova do backend, mas os defaults aqui evitam quebrar
      // se algum dia a rota for chamada num ambiente com backend
      // desatualizado (respostas antigas não tinham esses campos).
      joulesTotais: json['joules_totais'] ?? 0,
      fotonsTotais: json['fotons_totais'] ?? 0,
      nivelAtual: json['nivel_atual'] ?? 1,
    );
  }
}

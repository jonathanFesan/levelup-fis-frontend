import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/curriculum.dart';
import '../../domain/providers/exam_provider.dart';

/// Tela da Prova — layout deliberadamente diferente do resto do app
/// (fundo branco, texto preto, alternativas estilo ENEM) porque é pra
/// parecer avaliação de verdade, não o jogo.
///
/// Dois modos:
/// - 'facil': sem nenhuma restrição, só a prova.
/// - 'dificil': exige tela cheia, internet desligada ENQUANTO responde,
///   e avisa antes de sair que o progresso se perde.
///
/// FLUXO DO MODO DIFÍCIL (revisado nesta sessão): a prova precisa do
/// backend em dois momentos — buscar as questões no início e enviar as
/// respostas no fim — mas o modo difícil pede internet desligada. Isso
/// não dá pra reconciliar com "offline o tempo todo", então o fluxo
/// virou: (1) baixa a prova inteira ainda ONLINE (_FaseDificil.baixando),
/// (2) só depois passa a EXIGIR offline pra responder
/// (_FaseDificil.aguardandoOffline → emAndamento — ver enum abaixo), e
/// (3) ao confirmar "Finalizar", pede pra reativar a internet só pra
/// esse envio (_FaseDificil.aguardandoOnline). As respostas ficam em
/// memória (examProvider) o tempo todo, incluindo durante os dois
/// intervalos offline/online — nada se perde na troca.
///
/// LIMITAÇÃO IMPORTANTE (documentando pra ninguém assumir que o app
/// "desliga a internet do aparelho" — isso não é possível pra um app
/// comum, exige permissão de administrador de dispositivo/MDM): o que
/// esta tela faz é BLOQUEAR a resposta às questões enquanto detectar
/// conexão ativa, e pedir pro aluno desligar/religar manualmente — não
/// liga nem desliga nada sozinha.
///
/// NOVA DEPENDÊNCIA: usa `connectivity_plus`
/// (`flutter pub add connectivity_plus`).
class ExamScreen extends ConsumerStatefulWidget {
  final ModuloInfo modulo;
  final TopicoInfo topico;
  final String modo; // 'facil' | 'dificil'

  const ExamScreen({
    super.key,
    required this.modulo,
    required this.topico,
    required this.modo,
  });

  bool get isDificil => modo == 'dificil';

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

/// Fases da conexão no modo difícil. Só existe pra resolver uma
/// contradição real: a prova precisa do backend pra buscar as questões
/// e pra enviar as respostas, mas o modo difícil pede internet
/// desligada. A solução é não exigir os dois ao mesmo tempo: baixa tudo
/// ainda online, só então passa a exigir offline pra responder, e pede
/// pra reconectar de novo só na hora de enviar no final.
enum _FaseDificil {
  aguardandoOnlineInicial, // ainda não tentou baixar; internet desligada, pede pra ligar
  baixando, // chamando /exam/start, precisa estar online
  aguardandoOffline, // já baixou, esperando o aluno desligar a internet
  emAndamento, // offline confirmado, respondendo normalmente
  aguardandoOnline, // aluno confirmou "Finalizar", esperando internet voltar pra enviar
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  Timer? _relogio;
  Duration _tempoExibido = Duration.zero;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _verificandoConexao = false;
  bool _bloqueadoPorConexao = false;
  _FaseDificil _fase = _FaseDificil.aguardandoOnlineInicial;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _tempoExibido = ref.read(examProvider.notifier).tempoTotalDecorrido;
      });
    });

    if (widget.isDificil) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _checarConexaoInicial();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(examProvider.notifier).iniciar(
              topico: widget.topico.id,
              modo: widget.modo,
            );
      });
    }
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _connectivitySub?.cancel();
    if (widget.isDificil) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  bool _estaOnline(List<ConnectivityResult> resultados) =>
      resultados.isNotEmpty && !resultados.contains(ConnectivityResult.none);

  /// Passo 0 do modo difícil: confirma que há internet ANTES de tentar
  /// baixar — sem isso, a chamada HTTP podia ficar pendurada por muito
  /// tempo (sem timeout perceptível pro usuário) se o aluno já tivesse
  /// desligado a internet por hábito do fluxo antigo.
  Future<void> _checarConexaoInicial() async {
    final resultados = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (_estaOnline(resultados)) {
      await _iniciarFluxoDificil();
    } else {
      setState(() => _fase = _FaseDificil.aguardandoOnlineInicial);
    }
  }

  /// Passo 1 do modo difícil: baixa a prova inteira ENQUANTO ainda há
  /// internet (precisa dela pra chamar /exam/start). Só depois disso
  /// dado por concluído é que passamos a exigir offline. Mesmo com a
  /// checagem prévia, a chamada em si tem timeout (game_repository.dart)
  /// pra nunca travar indefinidamente caso a conexão caia no meio.
  Future<void> _iniciarFluxoDificil() async {
    setState(() => _fase = _FaseDificil.baixando);
    final ok = await ref.read(examProvider.notifier).iniciar(
          topico: widget.topico.id,
          modo: widget.modo,
        );
    if (!mounted || !ok) return; // erro tratado pela tela de erro genérica

    setState(() => _fase = _FaseDificil.aguardandoOffline);
    await _iniciarMonitoramentoConexao();
  }

  /// Checa o estado atual e passa a escutar mudanças de conectividade
  /// pelo resto da tela. Durante _FaseDificil.aguardandoOnline (envio
  /// final), a internet é esperada de propósito — o monitor não bloqueia
  /// nesse momento.
  Future<void> _iniciarMonitoramentoConexao() async {
    final resultados = await Connectivity().checkConnectivity();
    _atualizarEstadoConexao(resultados);

    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_atualizarEstadoConexao);
  }

  void _atualizarEstadoConexao(List<ConnectivityResult> resultados) {
    if (!mounted || _fase == _FaseDificil.aguardandoOnline) return;

    final online = _estaOnline(resultados);
    setState(() => _bloqueadoPorConexao = online);

    if (!online && _fase == _FaseDificil.aguardandoOffline) {
      setState(() => _fase = _FaseDificil.emAndamento);
    }
  }

  Future<void> _tentarBaixarNovamente() async {
    setState(() => _verificandoConexao = true);
    final resultados = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _verificandoConexao = false);
    if (_estaOnline(resultados)) {
      await _iniciarFluxoDificil();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ainda sem internet — tente de novo.')),
      );
    }
  }

  Future<void> _verificarConexaoManualmente() async {
    setState(() => _verificandoConexao = true);
    final resultados = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _verificandoConexao = false);
    _atualizarEstadoConexao(resultados);
  }

  String _formatarTempo(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<bool> _confirmarSaida() async {
    if (!widget.isDificil) return true;
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sair da prova?'),
        content: const Text(
          'Se você sair agora, todo o progresso e a pontuação desta '
          'tentativa serão perdidos. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar prova'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair mesmo assim'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _abrirGradeDeQuestoes() async {
    final examState = ref.read(examProvider);
    final escolha = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _GradeDeQuestoes(
        total: examState.questoes.length,
        respondidas: examState.respostas.keys.toSet(),
        atual: examState.questaoAtual,
      ),
    );
    if (escolha != null) {
      ref.read(examProvider.notifier).irParaQuestao(escolha);
    }
  }

  /// Roda uma vez, assim que finalizar() dá certo (nos três pontos de
  /// entrada: finalizar normal, finalizar já online no modo difícil, e
  /// finalizar depois de reconectar). Notifica, atualiza o histórico e
  /// fecha esta tela — como agora ExamScreen é sempre aberta a partir de
  /// ExamStatsScreen (ver map_screen.dart), fechar aqui já revela a
  /// tela de estatísticas atualizada por trás, sem precisar navegar
  /// explicitamente pra lá.
  void _tratarEnvioComSucesso() {
    ref.invalidate(examAttemptsProvider(widget.topico.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prova enviada com sucesso!')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmarFinalizacao() async {
    final examState = ref.read(examProvider);
    final naoRespondidas = examState.questoes.length - examState.respostas.length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar prova?'),
        content: Text(
          naoRespondidas > 0
              ? 'Você ainda tem $naoRespondidas questão(ões) sem resposta. '
                  'Depois de finalizar não é possível mudar nenhuma resposta.'
              : 'Todas as questões foram respondidas. Depois de finalizar '
                  'não é possível mudar nenhuma resposta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!widget.isDificil) {
      final ok = await ref.read(examProvider.notifier).finalizar();
      if (ok) _tratarEnvioComSucesso();
      return;
    }

    // Modo difícil: agora sim precisamos de internet de volta, só pra
    // enviar. Se já estiver online, envia direto; senão, mostra a tela
    // de "reative a internet" e só envia quando o aluno confirmar.
    setState(() => _fase = _FaseDificil.aguardandoOnline);
    final resultados = await Connectivity().checkConnectivity();
    if (_estaOnline(resultados)) {
      final ok = await ref.read(examProvider.notifier).finalizar();
      if (ok) _tratarEnvioComSucesso();
    }
    // Se não estiver online, a tela de _AguardandoOnlineParaEnviar já
    // assume o controle a partir daqui (build() abaixo cuida disso).
  }

  Future<void> _tentarEnviarComInternet() async {
    setState(() => _verificandoConexao = true);
    final resultados = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _verificandoConexao = false);

    if (!_estaOnline(resultados)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ainda sem internet — tente de novo.')),
      );
      return;
    }
    final ok = await ref.read(examProvider.notifier).finalizar();
    if (ok) _tratarEnvioComSucesso();
  }

  @override
  Widget build(BuildContext context) {
    final examState = ref.watch(examProvider);

    Widget body;
    // examState.finalizada é checado ANTES de tudo, de propósito: sem
    // isso, se o envio desse certo enquanto _fase ainda fosse
    // aguardandoOnline, a tela continuava presa em "reative a internet"
    // mesmo já tendo enviado (bug real desta sessão). Na prática, hoje
    // esse branch quase nunca chega a ser desenhado — _tratarEnvioComSucesso
    // já fecha a tela assim que finalizar() retorna true — mas fica
    // como rede de segurança caso o pop falhe por algum motivo.
    if (examState.finalizada) {
      body = _ResultadoProva(
        resultado: examState.resultado!,
        onVoltar: _tratarEnvioComSucesso,
      );
    } else if (widget.isDificil && _fase == _FaseDificil.aguardandoOnlineInicial) {
      body = _AguardandoOnlineInicial(
        onVerificarNovamente: _tentarBaixarNovamente,
        verificando: _verificandoConexao,
      );
    } else if (widget.isDificil && _fase == _FaseDificil.baixando) {
      body = examState.errorMessage != null
          ? _ErroProva(
              mensagem: examState.errorMessage!,
              onTentarNovamente: _iniciarFluxoDificil,
            )
          : const _BaixandoProva();
    } else if (widget.isDificil && _fase == _FaseDificil.aguardandoOnline) {
      body = examState.finalizando
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _AguardandoOnlineParaEnviar(
              onVerificarNovamente: _tentarEnviarComInternet,
              verificando: _verificandoConexao,
              erro: examState.errorMessage,
            );
    } else if (widget.isDificil && _bloqueadoPorConexao) {
      body = _BloqueioConexao(
        onVerificarNovamente: _verificarConexaoManualmente,
        verificando: _verificandoConexao,
      );
    } else if (examState.isLoading || examState.questoes.isEmpty) {
      body = examState.errorMessage != null
          ? _ErroProva(
              mensagem: examState.errorMessage!,
              onTentarNovamente: () => ref.read(examProvider.notifier).iniciar(
                    topico: widget.topico.id,
                    modo: widget.modo,
                  ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.black));
    } else {
      body = _CorpoProva(
        examState: examState,
        onAbrirGrade: _abrirGradeDeQuestoes,
        onFinalizar: _confirmarFinalizacao,
      );
    }

    final mostraRelogio = !examState.finalizada &&
        !_bloqueadoPorConexao &&
        _fase != _FaseDificil.aguardandoOnlineInicial &&
        _fase != _FaseDificil.baixando &&
        _fase != _FaseDificil.aguardandoOnline;

    final scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            final sair = await _confirmarSaida();
            if (!sair || !mounted) return;
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          '${widget.topico.titulo} · Prova',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (mostraRelogio)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      _formatarTempo(_tempoExibido),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );

    if (!widget.isDificil) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final sair = await _confirmarSaida();
        if (!sair || !mounted) return;
        Navigator.of(context).pop();
      },
      child: scaffold,
    );
  }
}

class _CorpoProva extends ConsumerWidget {
  final ExamState examState;
  final VoidCallback onAbrirGrade;
  final VoidCallback onFinalizar;

  const _CorpoProva({
    required this.examState,
    required this.onAbrirGrade,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questao = examState.questoes[examState.questaoAtual];
    final respostaAtual = examState.respostas[examState.questaoAtual];
    final ultimaQuestao =
        examState.questaoAtual == examState.questoes.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questão ${examState.questaoAtual + 1} de ${examState.questoes.length}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              TextButton.icon(
                onPressed: onAbrirGrade,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Todas as questões'),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questao.enunciado,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 24),
                if (questao.tipo == 'multipla_escolha' && questao.opcoes != null)
                  ..._letrasComOpcoes(questao.opcoes!).map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AlternativaEnem(
                        letra: o.letra,
                        texto: o.texto,
                        selecionada: respostaAtual == o.texto,
                        onTap: () => ref
                            .read(examProvider.notifier)
                            .responder(o.texto),
                      ),
                    ),
                  )
                else
                  TextField(
                    onChanged: (v) =>
                        ref.read(examProvider.notifier).responder(v),
                    controller: TextEditingController(text: respostaAtual)
                      ..selection = TextSelection.collapsed(
                        offset: (respostaAtual ?? '').length,
                      ),
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Sua resposta',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: examState.questaoAtual == 0
                      ? null
                      : () => ref
                          .read(examProvider.notifier)
                          .irParaQuestao(examState.questaoAtual - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: examState.finalizando
                      ? null
                      : ultimaQuestao
                          ? onFinalizar
                          : () => ref
                              .read(examProvider.notifier)
                              .irParaQuestao(examState.questaoAtual + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: examState.finalizando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(ultimaQuestao ? 'Finalizar' : 'Próxima'),
                ),
              ),
            ],
          ),
        ),
        if (examState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              examState.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  List<_OpcaoLetrada> _letrasComOpcoes(List<String> opcoes) {
    const letras = ['A', 'B', 'C', 'D', 'E', 'F'];
    return [
      for (var i = 0; i < opcoes.length; i++)
        _OpcaoLetrada(
          letra: i < letras.length ? letras[i] : '${i + 1}',
          texto: opcoes[i],
        ),
    ];
  }
}

class _OpcaoLetrada {
  final String letra;
  final String texto;
  const _OpcaoLetrada({required this.letra, required this.texto});
}

/// Alternativa estilo ENEM: círculo preto com a letra branca dentro.
/// Quando selecionada, o círculo vira a cor de destaque do app (dourado)
/// e o texto ganha uma borda/realce — adaptação do mesmo padrão do
/// `_OptionTile` de exercise_screen.dart, só que pro tema claro.
class _AlternativaEnem extends StatelessWidget {
  final String letra;
  final String texto;
  final bool selecionada;
  final VoidCallback onTap;

  const _AlternativaEnem({
    required this.letra,
    required this.texto,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const corDestaque = Color(0xFFB8860B); // dourado mais escuro, legível no branco

    return Material(
      color: selecionada ? corDestaque.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selecionada ? corDestaque : Colors.black26,
              width: selecionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selecionada ? corDestaque : Colors.black,
                ),
                child: Text(
                  letra,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeDeQuestoes extends StatelessWidget {
  final int total;
  final Set<int> respondidas;
  final int atual;

  const _GradeDeQuestoes({
    required this.total,
    required this.respondidas,
    required this.atual,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todas as questões',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toque em um número para ir direto pra questão.',
            style: TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(total, (i) {
              final respondida = respondidas.contains(i);
              final ehAtual = i == atual;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).pop(i),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ehAtual
                        ? Colors.black
                        : respondida
                            ? const Color(0xFFB8860B)
                            : Colors.white,
                    border: Border.all(
                      color: ehAtual || respondida
                          ? Colors.transparent
                          : Colors.black26,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: ehAtual || respondida ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Passo 0 do modo difícil — antes mesmo de tentar baixar. Só aparece
/// se a checagem inicial já encontrar internet desligada (ex: o aluno
/// desligou por hábito do fluxo antigo, antes de saber que agora
/// precisa dela pra baixar primeiro).
class _AguardandoOnlineInicial extends StatelessWidget {
  final VoidCallback onVerificarNovamente;
  final bool verificando;

  const _AguardandoOnlineInicial({
    required this.onVerificarNovamente,
    required this.verificando,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_rounded, size: 56, color: Colors.black87),
            const SizedBox(height: 16),
            const Text(
              'Ative a internet para baixar a prova',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No modo difícil, a internet só é necessária agora (pra '
              'baixar as questões) e no final (pra enviar). Ative o Wi-Fi '
              'ou os dados móveis e toque em "Verificar novamente".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: verificando ? null : onVerificarNovamente,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: verificando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verificar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fase 1 do modo difícil — baixando a prova inteira, ainda online.
class _BaixandoProva extends StatelessWidget {
  const _BaixandoProva();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 20),
            Text(
              'Baixando a prova...',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Depois disso você vai poder desligar a internet pra '
              'responder — ela só é necessária de novo no final, pra '
              'enviar a prova.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Última fase do modo difícil — aluno confirmou "Finalizar" mas o
/// aparelho ainda está offline (como devia estar até agora). Pede pra
/// reativar a internet só pra esse envio final; as respostas continuam
/// intactas em memória enquanto isso.
class _AguardandoOnlineParaEnviar extends StatelessWidget {
  final VoidCallback onVerificarNovamente;
  final bool verificando;
  final String? erro;

  const _AguardandoOnlineParaEnviar({
    required this.onVerificarNovamente,
    required this.verificando,
    this.erro,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_rounded, size: 56, color: Colors.black87),
            const SizedBox(height: 16),
            const Text(
              'Reative a internet para enviar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Suas respostas continuam salvas. Ligue o Wi-Fi ou os dados '
              'móveis de novo e toque em "Enviar prova" pra finalizar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.4),
            ),
            if (erro != null) ...[
              const SizedBox(height: 12),
              Text(erro!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: verificando ? null : onVerificarNovamente,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: verificando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar prova'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloqueioConexao extends StatelessWidget {
  final VoidCallback onVerificarNovamente;
  final bool verificando;

  const _BloqueioConexao({
    required this.onVerificarNovamente,
    required this.verificando,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.black87),
            const SizedBox(height: 16),
            const Text(
              'Desative a internet para continuar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O modo difícil exige que Wi-Fi e dados móveis estejam '
              'desligados durante toda a prova. Desligue manualmente nas '
              'configurações do aparelho e toque em "Verificar novamente".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: verificando ? null : onVerificarNovamente,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: verificando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verificar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErroProva extends StatelessWidget {
  final String mensagem;
  final VoidCallback onTentarNovamente;

  const _ErroProva({required this.mensagem, required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTentarNovamente,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultadoProva extends StatelessWidget {
  final Map<String, dynamic> resultado;
  final VoidCallback onVoltar;

  const _ResultadoProva({required this.resultado, required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    final acertos = resultado['acertos'] as int? ?? 0;
    final erros = resultado['erros'] as int? ?? 0;
    final tempoTotal = resultado['tempo_total_segundos'] as int? ?? 0;
    final total = acertos + erros;
    final tempoMedio = total > 0 ? tempoTotal / total : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFFB8860B)),
            const SizedBox(height: 16),
            const Text(
              'Prova finalizada',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 24),
            _LinhaResultado('Acertos', '$acertos'),
            _LinhaResultado('Erros', '$erros'),
            _LinhaResultado('Tempo total', _formatarSegundos(tempoTotal)),
            _LinhaResultado(
              'Tempo médio por questão',
              _formatarSegundos(tempoMedio.round()),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onVoltar,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Voltar à trilha'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarSegundos(int segundos) {
    final m = segundos ~/ 60;
    final s = segundos % 60;
    return '${m}min ${s}s';
  }
}

class _LinhaResultado extends StatelessWidget {
  final String label;
  final String valor;

  const _LinhaResultado(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(width: 12),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/progress_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/curriculo_provider.dart';
import '../../domain/providers/game_path_provider.dart';
import '../../domain/providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'result_screen.dart';

/// Quantidade máxima de Cargas do app (espelha VIDAS_MAXIMAS do backend,
/// em progress.py). Usado só pra desenhar o ícone "cheio vs. vazio" no
/// topo da tela — não é fonte de verdade, é puramente visual (o valor
/// real vem de userProvider, que já reflete a recarga automática por
/// tempo feita no backend).
const int _kCargasMaximas = 5;

/// Tela de Exercício — LevelUp Fís
///
/// Recebe o índice do nó atual (via GoRouter `extra`), exibe o enunciado
/// e as opções (múltipla escolha) ou um campo de texto (input_texto).
/// Ao responder, chama GameRepository.answerQuestion(), e:
/// - se acertou: userProvider.atualizarTotais() (reflete os totais que
///   o backend já calculou — ver progress_model.dart) +
///   gamePathProvider.completeNode()
/// - se errou: userProvider.removeVida()
/// Depois navega para a tela de resultado com o AnswerResultModel.
///
/// Layout desta sessão (redesign de UI, lógica de dados intocada):
/// - Topo: Cargas restantes (ícone de bateria), sem AppBar padrão.
/// - Linha discreta abaixo: módulo/tópico à esquerda, cronômetro da fase
///   à direita, mesma linha.
/// - Enunciado com fonte de leitura confortável (Lora, via google_fonts),
///   texto justificado.
/// - Alternativas letradas de A a D (mantém suporte a input de texto).
/// - Botão "Responder" largo, com espaço reservado para a logo abaixo.
class ExerciseScreen extends ConsumerStatefulWidget {
  final int nodeIndex;

  const ExerciseScreen({super.key, required this.nodeIndex});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  final _textController = TextEditingController();
  String? _opcaoSelecionada;
  bool _enviando = false;

  Timer? _timer;
  Duration _tempoDecorrido = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Cronômetro simples de "tempo de execução da fase" — conta a partir
    // do momento em que a tela abre. Só apresentação; não é enviado ao
    // backend nem persistido (não há campo pra isso no MVP ainda).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _tempoDecorrido += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  String get _tempoFormatado {
    final minutos =
        _tempoDecorrido.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos =
        _tempoDecorrido.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  /// Busca o [ModuloInfo] (ex: "Mecânica") dono do tópico da questão
  /// atual, olhando o currículo já carregado por curriculoProvider — é
  /// dali que vem tanto o título quanto o símbolo (emoji) do módulo, o
  /// mesmo usado no Mapa (ModuleStrip). Se não encontrar (currículo ainda
  /// carregando, com erro, ou tópico fora dele — ex: mock antigo),
  /// retorna null; a UI já trata esse caso mostrando só o título do
  /// tópico, sem símbolo.
  ModuloInfo? _moduloDoTopico(List<ModuloInfo> modulos, String topicoId) {
    for (final modulo in modulos) {
      if (modulo.topicos.any((t) => t.id == topicoId)) {
        return modulo;
      }
    }
    return null;
  }

  String _tituloTopico(List<ModuloInfo> modulos, String topicoId) {
    for (final modulo in modulos) {
      for (final topico in modulo.topicos) {
        if (topico.id == topicoId) return topico.titulo;
      }
    }
    return topicoId;
  }

  Future<void> _handleResponder() async {
    final pathState = ref.read(gamePathProvider);
    final node = pathState.nodes[widget.nodeIndex];
    final question = node.question;

    final resposta = question.tipo == 'multipla_escolha'
        ? _opcaoSelecionada
        : _textController.text.trim();

    if (resposta == null || resposta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ou digite uma resposta')),
      );
      return;
    }

    final accessToken = ref.read(authProvider).accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final repository = GameRepository();
      final AnswerResultModel resultado = await repository.answerQuestion(
        question.id,
        resposta,
        accessToken,
      );

      if (resultado.acertou) {
        // Não soma mais localmente — o backend já aplicou a recompensa
        // (incluindo retry pela metade e bônus de conclusão de
        // capítulo) e devolveu os totais prontos. Ver
        // user_provider.dart.atualizarTotais.
        ref.read(userProvider.notifier).atualizarTotais(
              joules: resultado.joulesTotais,
              fotons: resultado.fotonsTotais,
              nivel: resultado.nivelAtual,
            );
        ref.read(gamePathProvider.notifier).completeNode(widget.nodeIndex);
      } else {
        await ref.read(userProvider.notifier).removeVida();
      }

      _timer?.cancel();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultScreen(resultado: resultado)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar resposta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Combina cada opção com sua letra (A, B, C, D...), sem alterar a
  /// ordem em que vieram do backend.
  List<_OpcaoLetrada>? _letrasComOpcoes(List<String>? opcoes) {
    if (opcoes == null) return null;
    const letras = ['A', 'B', 'C', 'D', 'E', 'F'];
    return [
      for (var i = 0; i < opcoes.length; i++)
        _OpcaoLetrada(
          letra: i < letras.length ? letras[i] : '${i + 1}',
          texto: opcoes[i],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pathState = ref.watch(gamePathProvider);

    if (pathState.nodes.isEmpty || widget.nodeIndex >= pathState.nodes.length) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final node = pathState.nodes[widget.nodeIndex];
    final question = node.question;
    final userVidas = ref.watch(userProvider).user?.cargas ?? 0;
    final modulos = ref.watch(curriculoProvider).valueOrNull ?? [];

    final modulo = _moduloDoTopico(modulos, question.topico);
    final moduloTitulo = modulo?.titulo ?? '';
    final topicoTitulo = _tituloTopico(modulos, question.topico);
    final localizacao =
        moduloTitulo.isEmpty ? topicoTitulo : '$moduloTitulo · $topicoTitulo';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ---- Chances de erro (esquerda) + símbolo do módulo
              // (centralizado exatamente no meio da tela) ----
              SizedBox(
                height: 30,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    _CargasRestantes(
                      cargas: userVidas,
                      cargasMaximas: _kCargasMaximas,
                    ),
                    if (modulo != null)
                      Align(
                        alignment: Alignment.center,
                        child: _ModuloSymbol(modulo: modulo),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ---- Módulo/tópico (discreto, esquerda) + tempo (direita) ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      localizacao.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _tempoFormatado,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Enunciado ----
                      Text(
                        question.enunciado,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.lora(
                          fontSize: 19,
                          height: 1.5,
                          color: AppColors.textoQuaseBranco,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ---- Alternativas A-D ----
                      if (question.tipo == 'multipla_escolha')
                        ...?_letrasComOpcoes(question.opcoes)?.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OptionTile(
                              letra: entry.letra,
                              texto: entry.texto,
                              selecionado: _opcaoSelecionada == entry.texto,
                              onTap: () => setState(
                                () => _opcaoSelecionada = entry.texto,
                              ),
                            ),
                          ),
                        )
                      else
                        TextField(
                          controller: _textController,
                          style: const TextStyle(color: AppColors.cream),
                          cursorColor: AppColors.gold,
                          decoration: InputDecoration(
                            labelText: 'Sua resposta',
                            labelStyle: const TextStyle(color: AppColors.muted),
                            filled: true,
                            fillColor: AppColors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.gold,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Botão largo "Responder" ----
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _enviando ? null : _handleResponder,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.bg,
                          ),
                        )
                      : const Text(
                          'RESPONDER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Espaço reservado para a logo do app.
              // Trocar este SizedBox por
              // Image.asset('assets/logo/logo_mark.png', height: 28)
              // quando o asset final da marca for adicionado ao pubspec.
              const SizedBox(height: 28),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcaoLetrada {
  final String letra;
  final String texto;
  const _OpcaoLetrada({required this.letra, required this.texto});
}

/// Selo circular com o símbolo do módulo atual — o mesmo `emoji` definido
/// em [ModuloInfo] (curriculum.dart), que é exatamente o que a
/// ModuleStrip desenha no Mapa. Fica centralizado no topo, como
/// referência discreta de "em que módulo você está".
class _ModuloSymbol extends StatelessWidget {
  final ModuloInfo modulo;

  const _ModuloSymbol({required this.modulo});

  @override
  Widget build(BuildContext context) {
    const size = 26.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card.withValues(alpha: 0.6),
      ),
      child: Opacity(
        opacity: 0.8,
        child: Text(modulo.emoji, style: const TextStyle(fontSize: 13, height: 1)),
      ),
    );
  }
}

/// Cargas restantes, estilo bateria: cheia = carga disponível, vazia =
/// carga já perdida. Ícone/cor trocados nesta sessão (era coração
/// vermelho, "vidas") pra combinar com o tema "Cargas/bateria" do
/// documento de Economia e Nomenclatura.
class _CargasRestantes extends StatelessWidget {
  final int cargas;
  final int cargasMaximas;

  const _CargasRestantes({required this.cargas, required this.cargasMaximas});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(cargasMaximas, (i) {
        final carregada = i < cargas;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            carregada ? Icons.battery_full_rounded : Icons.battery_0_bar_rounded,
            size: 22,
            color: carregada ? AppColors.gold : AppColors.muted,
          ),
        );
      }),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letra;
  final String texto;
  final bool selecionado;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letra,
    required this.texto,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selecionado ? AppColors.gold.withValues(alpha: 0.14) : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionado ? AppColors.gold : AppColors.divider,
              width: selecionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selecionado ? AppColors.gold : AppColors.bg,
                  border: selecionado
                      ? null
                      : Border.all(color: AppColors.gold, width: 1.4),
                ),
                child: Text(
                  letra,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    // Dourado sobre navy (não selecionado) ou navy sobre
                    // dourado (selecionado) — sempre alto contraste, em
                    // vez do cream apagado sobre lockedFill de antes.
                    color: selecionado ? AppColors.bg : AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: AppColors.textoQuaseBranco,
                    fontSize: 15,
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
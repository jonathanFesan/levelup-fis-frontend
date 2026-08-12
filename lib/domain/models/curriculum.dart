// Arquivo: frontend/lib/domain/models/curriculum.dart
// Modelo de domínio do currículo consumido pelas telas — ModuloInfo
// (Área) e TopicoInfo (Bloco).
//
// ATUALIZADO NA FASE 1 DO CURRÍCULO DINÂMICO: até aqui, `kCurriculo` era
// uma constante estática com TODAS as Áreas e Blocos hardcoded. Agora
// Áreas e Blocos reais vêm do backend (GET /curriculo/areas, editável
// pelo painel — ver sql/010_curriculo_dinamico.sql) através de
// curriculoProvider (domain/providers/curriculo_provider.dart), que monta
// a `List<ModuloInfo>` a partir de `List<AreaModel>`
// (data/models/curriculo_model.dart). Nada mais nesse arquivo lê da rede
// — ele só define o formato que as telas já conheciam.
//
// Os blocos de pré-visualização de UI (Dinâmica/Estática/Fluidos, com
// `mockExercicios`, sem pergunta real por trás) que existiam aqui como
// `kBlocosMockMecanica` foram REMOVIDOS a pedido do cliente — apareciam
// no Mapa mesmo sem estar cadastrados no painel/banco, o que confundia
// quem via o app. `mockExercicios` continua existindo em TopicoInfo como
// ferramenta genérica de teste visual, só que sem nenhum bloco hardcoded
// usando ela hoje.

class TopicoInfo {
  final String id;
  final String titulo;

  /// Se já existe conteúdo real (questões cadastradas no backend) para
  /// este tópico. Hoje: `introducao` e `cinematica`, ambos vindos da API.
  final bool implementado;

  /// Quantidade de nós de teste/preview pra essa trilha, usado SÓ PARA
  /// TESTAR A UI quando o tópico ainda não tem perguntas reais no
  /// backend. Se preenchido (e `implementado` for false), o tópico abre
  /// uma trilha com esse número de nós falsos (sem pergunta de verdade
  /// por trás) em vez de aparecer bloqueado como "Em breve".
  ///
  /// Isto é só uma ferramenta de teste visual — só existe hoje nos
  /// blocos de `kBlocosMockMecanica`, abaixo.
  final int? mockExercicios;

  /// Nível GLOBAL mínimo (profiles.nivel) que o aluno precisa ter para
  /// abrir este tópico — trava por nível, somada à trava por sequência
  /// (tópico anterior do mesmo módulo com Fixação concluída, ver
  /// topicoDesbloqueadoProvider em topic_progress_provider.dart). As
  /// DUAS regras precisam valer juntas.
  ///
  /// Para blocos reais, este valor vem de `blocos.nivel_minimo` (banco,
  /// editável pelo painel) — ver curriculo_provider.dart. O admin ainda
  /// pode sobrescrever por tópico direto em topic_content.nivel_minimo
  /// (ver sql/008_nivel_minimo_editavel.sql); se nenhum dos dois foi
  /// definido, topicoDesbloqueadoProvider cai pro valor default abaixo
  /// (1) como último fallback.
  final int nivelMinimo;

  const TopicoInfo({
    required this.id,
    required this.titulo,
    this.implementado = false,
    this.mockExercicios,
    this.nivelMinimo = 1,
  });

  /// Se este tópico pode ser aberto (com conteúdo real OU em modo de
  /// teste/preview).
  bool get navegavel => implementado || mockExercicios != null;
}

/// Um "bloco grande" do currículo (ex: Mecânica, Termologia...).
class ModuloInfo {
  final String id;
  final String titulo;

  /// Emoji vindo de `areas.icone` (ex: '⚙️') — ver decisão em
  /// sql/010_curriculo_dinamico.sql. Substitui os antigos `icon`
  /// (IconData) e `customIconBuilder` (usados só enquanto os ícones eram
  /// hardcoded no Dart).
  final String emoji;

  final List<TopicoInfo> topicos;

  const ModuloInfo({
    required this.id,
    required this.titulo,
    required this.emoji,
    required this.topicos,
  });

  /// Um módulo é considerado "com conteúdo real" se pelo menos um dos
  /// seus tópicos já está implementado no backend.
  bool get implementado => topicos.any((t) => t.implementado);

  /// Um módulo fica navegável na faixa de módulos se tiver pelo menos um
  /// tópico navegável (real OU em modo de teste).
  bool get navegavel => topicos.any((t) => t.navegavel);
}

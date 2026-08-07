// Arquivo: frontend/lib/data/models/user_model.dart
// Modelo de dados do usuário
//
// Atualizado nesta sessão: o app agora chama xp/moedas/vidas de
// Joules/Fótons/Cargas na tela (ver documento "Economia e
// Nomenclatura"). Os campos e o JSON continuam com os nomes antigos de
// propósito — trocar nome de coluna no banco seria arriscado e exigiria
// mexer em muito mais lugares sem ganho real. `cargas`/`joules`/
// `fotons` abaixo são só getters (mesmo dado, nome de exibição) — use
// eles no código de UI daqui pra frente; `vidas`/`xp`/`moedas` continuam
// existindo pra não quebrar nada que já lê esses nomes.

class UserModel {
  final String id;
  final String email;
  final int xp;
  final int moedas;
  final int vidas;
  final int nivel;
  final DateTime? vidasAtualizadoEm;

  /// Nome de exibição (ver sql/007_nome_perfil.sql). Pode ser null em
  /// contas antigas que ainda não definiram um nome — nesse caso a UI
  /// deve cair para um fallback (ex: prefixo do e-mail), nunca mostrar
  /// null na tela.
  final String? nome;

  /// Reflete profiles.is_admin (ver sql/002_admin_perguntas.sql). Usado
  /// no app só para liberar, para o admin, tópicos ainda em modo de
  /// teste (mockExercicios) sem essa trava aparecer para alunos reais —
  /// ver curriculum.dart e topic_progress_provider.dart.
  final bool isAdmin;

  UserModel({
    required this.id,
    required this.email,
    required this.xp,
    required this.moedas,
    required this.vidas,
    required this.nivel,
    this.vidasAtualizadoEm,
    this.nome,
    this.isAdmin = false,
  });

  // Apelidos temáticos — ver nota no topo do arquivo.
  int get joules => xp;
  int get fotons => moedas;
  int get cargas => vidas;

  /// Quanto tempo falta pra próxima Carga recarregar (1 a cada 4h),
  /// ou null se já estiver no máximo ou não houver dado suficiente pra
  /// calcular. É só uma estimativa pro Flutter mostrar um contador —
  /// o valor real de `vidas` já vem recarregado do backend a cada
  /// GET /profile (ver progress.py), isso aqui não substitui aquilo.
  Duration? get tempoAteProximaCarga {
    if (vidas >= 5 || vidasAtualizadoEm == null) return null;
    final proximaCarga = vidasAtualizadoEm!.add(const Duration(hours: 4));
    final restante = proximaCarga.difference(DateTime.now());
    return restante.isNegative ? Duration.zero : restante;
  }

  // Cria um UserModel a partir do JSON que vem da API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      xp: json['xp'] ?? 0,
      moedas: json['moedas'] ?? 0,
      vidas: json['vidas'] ?? 5,
      nivel: json['nivel'] ?? 1,
      vidasAtualizadoEm: json['vidas_atualizado_em'] != null
          ? DateTime.tryParse(json['vidas_atualizado_em'])
          : null,
      nome: json['nome'] as String?,
      isAdmin: json['is_admin'] ?? false,
    );
  }

  // Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'xp': xp,
      'moedas': moedas,
      'vidas': vidas,
      'nivel': nivel,
      'nome': nome,
    };
  }

  // Cria uma cópia com campos alterados (útil para atualizar estado)
  UserModel copyWith({
    int? xp,
    int? moedas,
    int? vidas,
    int? nivel,
    DateTime? vidasAtualizadoEm,
    String? nome,
    bool? isAdmin,
  }) {
    return UserModel(
      id: id,
      email: email,
      xp: xp ?? this.xp,
      moedas: moedas ?? this.moedas,
      vidas: vidas ?? this.vidas,
      nivel: nivel ?? this.nivel,
      vidasAtualizadoEm: vidasAtualizadoEm ?? this.vidasAtualizadoEm,
      nome: nome ?? this.nome,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  /// Nome pronto para exibição na UI: usa [nome] se já foi definido;
  /// senão cai para a parte antes do @ do e-mail (nunca mostra null nem
  /// o e-mail completo, exceto como último recurso se nem e-mail houver).
  String get nomeExibicao {
    if (nome != null && nome!.trim().isNotEmpty) return nome!.trim();
    if (email.contains('@')) return email.split('@').first;
    return email.isNotEmpty ? email : 'Aluno';
  }
}

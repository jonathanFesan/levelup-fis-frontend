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

  UserModel({
    required this.id,
    required this.email,
    required this.xp,
    required this.moedas,
    required this.vidas,
    required this.nivel,
    this.vidasAtualizadoEm,
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
    };
  }

  // Cria uma cópia com campos alterados (útil para atualizar estado)
  UserModel copyWith({
    int? xp,
    int? moedas,
    int? vidas,
    int? nivel,
    DateTime? vidasAtualizadoEm,
  }) {
    return UserModel(
      id: id,
      email: email,
      xp: xp ?? this.xp,
      moedas: moedas ?? this.moedas,
      vidas: vidas ?? this.vidas,
      nivel: nivel ?? this.nivel,
      vidasAtualizadoEm: vidasAtualizadoEm ?? this.vidasAtualizadoEm,
    );
  }
}

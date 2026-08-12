// Arquivo: frontend/lib/domain/providers/curriculo_provider.dart
// Currículo dinâmico (Fase 1): busca Áreas + Blocos do backend
// (GET /curriculo/areas, editável pelo painel — ver
// backend/sql/010_curriculo_dinamico.sql) e monta a `List<ModuloInfo>`
// que o resto do app já sabia consumir, no formato que
// domain/models/curriculum.dart define.
//
// Substitui a constante estática `kCurriculo` que existia antes direto em
// curriculum.dart. Mesmo padrão de outros FutureProviders do projeto (ex:
// topicContentProvider): quem consome trata loading/erro com `.when()`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/models/curriculo_model.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/models/curriculum.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

/// Converte as Áreas/Blocos crus da API para o formato de domínio já
/// consumido pelas telas. Só usa o que veio do banco — sem blocos
/// hardcoded de pré-visualização (ver curriculum.dart: os blocos mock de
/// Dinâmica/Estática/Fluidos foram removidos por pedido do cliente, já
/// que eles apareciam no app mesmo sem existir no painel/banco).
List<ModuloInfo> _paraModuloInfo(List<AreaModel> areas) {
  return areas.map((area) {
    final topicos = area.blocos
        .map((b) => TopicoInfo(
              id: b.id,
              titulo: b.titulo,
              implementado: true,
              nivelMinimo: b.nivelMinimo,
            ))
        .toList();

    return ModuloInfo(
      id: area.id,
      titulo: area.titulo,
      emoji: area.icone,
      topicos: topicos,
    );
  }).toList();
}

final curriculoProvider = FutureProvider<List<ModuloInfo>>((ref) async {
  final accessToken = ref.watch(authProvider).accessToken;
  if (accessToken == null) return [];
  final repository = GameRepository();
  final areas = await repository.getCurriculo(accessToken);
  return _paraModuloInfo(areas);
});

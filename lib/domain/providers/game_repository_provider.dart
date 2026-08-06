import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/game_repository.dart';

/// Expõe uma instância única de GameRepository via Riverpod, para que
/// as telas (como exercise_screen.dart) não precisem instanciá-lo
/// manualmente.
///
/// Ajuste o construtor abaixo se GameRepository exigir parâmetros
/// (ex: um client http customizado) — no handoff ele aparece sem
/// dependências explícitas além de AppConstants.baseUrl, usado
/// internamente.
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository();
});

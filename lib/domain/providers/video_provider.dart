// Arquivo: frontend/lib/domain/providers/video_provider.dart
// Gerencia a lista de vídeos (curtas do cotidiano + aulas completas).
//
// Segue o mesmo desenho de game_path_provider.dart e user_provider.dart:
// StateNotifier que lê authProvider.accessToken pra autenticar a
// chamada. Diferente de game_path_provider.dart, não implementa cache
// por topico+categoria por enquanto — se a tela de Vídeos ganhar filtro
// por tópico com troca frequente, vale replicar aquele padrão aqui
// (ver seção 5.2 do handoff).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup_fis/data/models/video_model.dart';
import 'package:levelup_fis/data/repositories/game_repository.dart';
import 'package:levelup_fis/domain/providers/auth_provider.dart';

class VideoState {
  final bool isLoading;
  final List<VideoModel> videos;
  final String? errorMessage;

  VideoState({
    this.isLoading = false,
    this.videos = const [],
    this.errorMessage,
  });

  List<VideoModel> get curtas =>
      videos.where((v) => v.tipoVideo == 'curta_cotidiano').toList();

  List<VideoModel> get aulasCompletas =>
      videos.where((v) => v.tipoVideo == 'aula_completa').toList();

  VideoState copyWith({
    bool? isLoading,
    List<VideoModel>? videos,
    String? errorMessage,
  }) {
    return VideoState(
      isLoading: isLoading ?? this.isLoading,
      videos: videos ?? this.videos,
      errorMessage: errorMessage,
    );
  }
}

class VideoNotifier extends StateNotifier<VideoState> {
  final GameRepository _gameRepository;
  final Ref _ref;

  VideoNotifier(this._gameRepository, this._ref) : super(VideoState());

  Future<void> loadVideos({String? topico}) async {
    final accessToken = _ref.read(authProvider).accessToken;
    if (accessToken == null) {
      state = state.copyWith(
        errorMessage: 'Sessão expirada. Faça login novamente.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final videos =
          await _gameRepository.getVideos(accessToken, topico: topico);
      state = state.copyWith(isLoading: false, videos: videos);
    } catch (e) {
      // DIAGNÓSTICO TEMPORÁRIO — remover depois de achar a causa raiz.
      debugPrint('[loadVideos] erro real: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar vídeos.',
      );
    }
  }

  /// Marca um vídeo como assistido: atualização otimista local (igual ao
  /// padrão de user_provider.dart.addReward) + sincroniza com o backend.
  Future<void> marcarAssistido(int videoId) async {
    final accessToken = _ref.read(authProvider).accessToken;
    if (accessToken == null) return;

    state = state.copyWith(
      videos: [
        for (final v in state.videos)
          if (v.id == videoId) v.copyWith(assistido: true) else v,
      ],
    );

    try {
      await _gameRepository.markVideoWatched(accessToken, videoId);
    } catch (_) {
      // Falha silenciosa por enquanto: o aluno já viu o vídeo mesmo se o
      // registro no backend falhar. Se quiserem feedback de erro aqui
      // (ex: reverter o estado otimista), é só ajustar este catch.
    }
  }
}

final videoProvider = StateNotifierProvider<VideoNotifier, VideoState>((ref) {
  return VideoNotifier(GameRepository(), ref);
});
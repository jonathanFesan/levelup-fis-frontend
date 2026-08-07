import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/video_model.dart';
import '../../domain/providers/video_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/exercise_trail.dart' show TrailStarfield;

/// Tela de Vídeos — LevelUp Fís.
///
/// Duas seções, como descrito na seção 1 e 7.3 do handoff (diferencial
/// de produto ainda não implementado até esta sessão):
/// - Carrossel horizontal de "curtas do cotidiano" (física conectada a
///   situações reais), com bloqueio por nível (nivel_desbloqueio).
/// - Lista vertical de aulas completas.
///
/// Os vídeos hoje são links externos (URLs do YouTube, ver dados de
/// exemplo no SQL de vídeos) — não há player embutido nesta sessão, só
/// abre o link externamente via url_launcher. Se quiserem um player
/// dentro do app no futuro, é uma tela bem diferente (provavelmente
/// precisa de um pacote tipo youtube_player_flutter).
///
/// NOVA DEPENDÊNCIA: esta tela usa o pacote `url_launcher`. Se ainda não
/// estiver no pubspec.yaml, rodar `flutter pub add url_launcher`.
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoProvider.notifier).loadVideos();
    });
  }

  Future<void> _abrirVideo(VideoModel video) async {
    if (!video.desbloqueado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Esse vídeo desbloqueia no nível ${video.nivelDesbloqueio}. '
            'Continue completando exercícios para subir de nível!',
          ),
        ),
      );
      return;
    }

    ref.read(videoProvider.notifier).marcarAssistido(video.id);

    final uri = Uri.tryParse(video.urlVideo);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o vídeo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TrailStarfield()),
          SafeArea(
            bottom: false,
            child: videoState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : videoState.errorMessage != null
                    ? _ErrorState(
                        message: videoState.errorMessage!,
                        onRetry: () =>
                            ref.read(videoProvider.notifier).loadVideos(),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                            child: Text(
                              'Vídeos',
                              style: TextStyle(
                                color: AppColors.textoQuaseBranco,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (videoState.curtas.isNotEmpty) ...[
                            const _SectionTitle('Física no seu dia a dia'),
                            _CurtasCarousel(
                              curtas: videoState.curtas,
                              onTap: _abrirVideo,
                            ),
                          ],
                          if (videoState.aulasCompletas
                              .any((a) => a.desbloqueado)) ...[
                            const _SectionTitle('Aulas completas'),
                            for (final aula in videoState.aulasCompletas)
                              if (aula.desbloqueado)
                                _AulaCompletaTile(
                                  video: aula,
                                  onTap: () => _abrirVideo(aula),
                                ),
                          ],
                          if (videoState.curtas.isEmpty &&
                              !videoState.aulasCompletas
                                  .any((a) => a.desbloqueado))
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'Nenhum vídeo disponível ainda.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentTab: AppNavTab.videos,
        onSelect: (tab) {
          switch (tab) {
            case AppNavTab.mapa:
              context.go('/map');
              break;
            case AppNavTab.videos:
              break;
            case AppNavTab.perfil:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.cream,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CurtasCarousel extends StatelessWidget {
  final List<VideoModel> curtas;
  final ValueChanged<VideoModel> onTap;

  const _CurtasCarousel({required this.curtas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: curtas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final video = curtas[index];
          return _CurtaCard(video: video, onTap: () => onTap(video));
        },
      ),
    );
  }
}

class _CurtaCard extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const _CurtaCard({required this.video, required this.onTap});

  String _formatarDuracao(int segundos) {
    final min = segundos ~/ 60;
    final seg = segundos % 60;
    return '$min:${seg.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bloqueado = !video.desbloqueado;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: video.assistido
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.divider,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: bloqueado ? AppColors.muted : AppColors.gold,
                      size: 36,
                    ),
                    const Spacer(),
                    Text(
                      video.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bloqueado
                            ? AppColors.muted
                            : AppColors.textoQuaseBranco,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatarDuracao(video.duracaoSegundos),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (bloqueado)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.lock_rounded,
                    color: AppColors.muted, size: 18),
              ),
            if (video.assistido)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _AulaCompletaTile extends StatelessWidget {
  final VideoModel video;
  final VoidCallback onTap;

  const _AulaCompletaTile({required this.video, required this.onTap});

  String _formatarDuracao(int segundos) {
    final min = segundos ~/ 60;
    return '$min min';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.bg, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.titulo,
                        style: const TextStyle(
                          color: AppColors.textoQuaseBranco,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatarDuracao(video.duracaoSegundos),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (video.assistido)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20)
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cream),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
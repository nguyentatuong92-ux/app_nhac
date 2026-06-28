import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'home_screen.dart';
import 'music_controller.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final MusicController musicController = MusicController();
    final accentColor = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<MediaItem?>(
      valueListenable: musicController.currentItem,
      builder: (context, item, _) {
        if (item == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
          child: Container(
            height: 75,
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(35),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Hero(
                        tag: 'music_artwork',
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            color: const Color(0xFF4B5563),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildArtwork(item, accentColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextScroll(
                              item.title,
                              mode: TextScrollMode.bouncing,
                              velocity: const Velocity(
                                pixelsPerSecond: Offset(30, 0),
                              ),
                              delayBefore: const Duration(seconds: 2),
                              pauseBetween: const Duration(seconds: 2),
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.artist ?? "Không biết",
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_previous, color: accentColor),
                        onPressed: () {
                          if (musicController.audioPlayer.hasPrevious) {
                            musicController.audioPlayer.seekToPrevious();
                          }
                        },
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: musicController.isPlaying,
                        builder: (context, playing, _) {
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: accentColor,
                              size: 35,
                            ),
                            onPressed: () {
                              playing
                                  ? musicController.audioPlayer.pause()
                                  : musicController.audioPlayer.play();
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next, color: accentColor),
                        onPressed: () {
                          if (musicController.audioPlayer.hasNext) {
                            musicController.audioPlayer.seekToNext();
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                _buildProgressBar(musicController, accentColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtwork(MediaItem item, Color accentColor) {
    if (item.extras?['is_online'] == true) {
      return Image.network(
        item.artUri?.toString() ?? "",
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.music_note, color: accentColor),
      );
    } else {
      return QueryArtworkWidget(
        id: int.tryParse(item.id) ?? 0,
        type: ArtworkType.AUDIO,
        artworkFit: BoxFit.cover,
        nullArtworkWidget: Icon(Icons.music_note, color: accentColor),
      );
    }
  }

  Widget _buildProgressBar(MusicController musicController, Color accentColor) {
    return StreamBuilder<Duration>(
      stream: musicController.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = musicController.audioPlayer.duration ?? Duration.zero;
        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
          progress = (position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
        }

        return Container(
          height: 3,
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(35),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 3,
            ),
          ),
        );
      },
    );
  }
}

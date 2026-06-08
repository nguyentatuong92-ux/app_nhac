import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import '../home_screen.dart';

class MiniPlayer extends StatelessWidget {
  final SongModel currentSong;
  final AudioPlayer audioPlayer;
  final VoidCallback onRefresh;

  const MiniPlayer({
    super.key,
    required this.currentSong,
    required this.audioPlayer,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(audioPlayer: audioPlayer),
        ),
      ).then((_) => onRefresh()),
      child: Container(
        height:
            75, // ĐÃ SỬA: Tăng lên 75 để rộng rãi hơn khi có thanh tiến trình
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3A),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: QueryArtworkWidget(
                      id: currentSong.id,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: Container(
                        color: Color(0xFF4B5563),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextScroll(
                          currentSong.title,
                          mode: TextScrollMode.bouncing,
                          velocity: const Velocity(
                            pixelsPerSecond: Offset(30, 0),
                          ),
                          delayBefore: const Duration(seconds: 2),
                          pauseBetween: const Duration(seconds: 2),
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentSong.artist ?? "Không biết",
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () {
                      if (audioPlayer.hasPrevious) audioPlayer.seekToPrevious();
                    },
                  ),
                  StreamBuilder<bool>(
                    stream: audioPlayer.playingStream,
                    builder: (context, snapshot) {
                      bool isPlaying = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.tealAccent,
                          size: 35,
                        ),
                        onPressed: () {
                          isPlaying ? audioPlayer.pause() : audioPlayer.play();
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.tealAccent),
                    onPressed: () {
                      if (audioPlayer.hasNext) audioPlayer.seekToNext();
                    },
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),

            StreamBuilder<Duration>(
              stream: audioPlayer.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = audioPlayer.duration ?? Duration.zero;

                double progress = 0.0;
                if (duration.inMilliseconds > 0) {
                  progress = position.inMilliseconds / duration.inMilliseconds;
                }

                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(35),
                  ),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.tealAccent,
                    ),
                    minHeight: 3,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:text_scroll/text_scroll.dart';
import 'online_music_controller.dart';
import 'home_screen.dart';

class OnlinePlaylistDetailsScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;

  const OnlinePlaylistDetailsScreen({super.key, required this.audioPlayer});

  @override
  State<OnlinePlaylistDetailsScreen> createState() =>
      _OnlinePlaylistDetailsScreenState();
}

class _OnlinePlaylistDetailsScreenState
    extends State<OnlinePlaylistDetailsScreen> {
  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0x901E293B),
      appBar: AppBar(
        title: const Text(
          'Danh sách nhạc Online',
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.tealAccent),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.tealAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<Video>>(
        valueListenable: OnlineMusicController.onlinePlaylist,
        builder: (context, playlist, _) {
          if (playlist.isEmpty) {
            return const Center(
              child: Text(
                'Danh sách trống.\nHãy thêm bài hát từ tab Online!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: playlist.length,
            onReorder: (oldIndex, newIndex) {
              OnlineMusicController.reorderInSavedAndActiveQueue(
                oldIndex,
                newIndex,
                widget.audioPlayer,
              );
            },
            itemBuilder: (context, index) {
              final video = playlist[index];

              // Kiểm tra xem bài này có đang phát không
              final currentItem =
                  widget.audioPlayer.sequenceState?.currentSource?.tag
                      as MediaItem?;
              final isPlaying =
                  currentItem?.id == video.id.value &&
                  OnlineMusicController.currentQueueType.value == "playlist";

              return ListTile(
                key: ValueKey(video.id.value + index.toString()),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    video.thumbnails.mediumResUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                title: TextScroll(
                  video.title,
                  mode: TextScrollMode.bouncing,
                  velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                  delayBefore: const Duration(seconds: 2),
                  pauseBetween: const Duration(seconds: 2),
                  style: TextStyle(
                    color: isPlaying ? Colors.tealAccent : Colors.white,
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying
                              ? Colors.tealAccent
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                    Text(
                      " • ${_formatDuration(video.duration)}",
                      style: TextStyle(
                        color: isPlaying ? Colors.tealAccent : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPlaying)
                      const Icon(Icons.equalizer, color: Colors.tealAccent),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.indigoAccent,
                      ),
                      onPressed: () {
                        OnlineMusicController.removeFromSavedAndActiveQueue(
                          index,
                          widget.audioPlayer,
                        );
                      },
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey),
                  ],
                ),
                onTap: () async {
                  await OnlineMusicController.playSong(
                    index,
                    widget.audioPlayer,
                    context,
                    customQueue: OnlineMusicController.onlinePlaylist.value,
                    queueType: "playlist",
                  );

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

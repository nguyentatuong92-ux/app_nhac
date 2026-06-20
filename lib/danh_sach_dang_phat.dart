import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'online_music_controller.dart';

class DanhSachDangPhat extends StatelessWidget {
  final AudioPlayer audioPlayer;

  const DanhSachDangPhat({super.key, required this.audioPlayer});

  static void show(BuildContext context, AudioPlayer audioPlayer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DanhSachDangPhat(audioPlayer: audioPlayer),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex ?? -1;

        // Xác định loại nhạc đang phát dựa trên bài hát hiện tại
        final currentSource = state?.currentSource;
        final currentMediaItem = currentSource?.tag as MediaItem?;
        final isOnline = currentMediaItem?.extras?['is_online'] == true;

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
              // 1. Thanh Tiêu đề
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOnline ? Icons.language : Icons.queue_music,
                      color: Colors.tealAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOnline
                          ? (OnlineMusicController.currentQueueType.value ==
                                    "playlist"
                                ? "Danh sách Online"
                                : "Kết quả tìm kiếm")
                          : 'Danh sách phát',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.tealAccent, height: 1),

              // 2. Danh sách bài hát
              Expanded(
                child: sequence.isEmpty
                    ? const Center(
                        child: Text(
                          'Hàng đợi trống.',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: sequence.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (oldIndex < newIndex) newIndex -= 1;
                          try {
                            final audioSource =
                                audioPlayer.audioSource
                                    as ConcatenatingAudioSource?;
                            if (audioSource != null) {
                              await audioSource.move(oldIndex, newIndex);

                              // Nếu là nhạc Online, cần cập nhật onlineQueue trong controller
                              if (isOnline) {
                                final video = OnlineMusicController.onlineQueue
                                    .removeAt(oldIndex);
                                OnlineMusicController.onlineQueue.insert(
                                  newIndex,
                                  video,
                                );
                                OnlineMusicController.currentIndex.value =
                                    audioPlayer.currentIndex ?? -1;
                              }
                            }
                          } catch (e) {
                            debugPrint("Lỗi di chuyển: $e");
                          }
                        },
                        itemBuilder: (context, index) {
                          final itemMedia = sequence[index].tag as MediaItem;
                          final isPlaying = index == currentIndex;
                          final isItemOnline =
                              itemMedia.extras?['is_online'] == true;

                          return ListTile(
                            key: ValueKey(itemMedia.id + index.toString()),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFF4B5563),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: isItemOnline
                                  ? Image.network(
                                      itemMedia.artUri?.toString() ?? "",
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.music_note,
                                                color: Colors.tealAccent,
                                              ),
                                    )
                                  : QueryArtworkWidget(
                                      id: int.tryParse(itemMedia.id) ?? 0,
                                      type: ArtworkType.AUDIO,
                                      nullArtworkWidget: const Icon(
                                        Icons.music_note,
                                        color: Colors.tealAccent,
                                      ),
                                    ),
                            ),
                            title: Text(
                              itemMedia.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying
                                    ? Colors.tealAccent
                                    : Colors.white,
                                fontWeight: isPlaying
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              "${itemMedia.artist ?? 'Không rõ'} • ${_formatDuration(itemMedia.duration)}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying
                                    ? Colors.tealAccent
                                    : Colors.grey[400],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPlaying)
                                  const Icon(
                                    Icons.equalizer,
                                    color: Colors.tealAccent,
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.indigo,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final audioSource =
                                        audioPlayer.audioSource
                                            as ConcatenatingAudioSource?;
                                    if (audioSource != null &&
                                        audioSource.length > index) {
                                      // 1. Đồng bộ xóa trong danh sách lưu trữ nếu đang phát từ Playlist
                                      if (isOnline &&
                                          OnlineMusicController
                                                  .currentQueueType
                                                  .value ==
                                              "playlist") {
                                        await OnlineMusicController.syncRemoveFromPlaylist(
                                          itemMedia,
                                        );
                                      }

                                      // 2. Xóa khỏi hàng đợi vật lý của trình phát
                                      await audioSource.removeAt(index);

                                      // 3. Cập nhật hàng đợi online để đồng bộ UI
                                      if (isOnline) {
                                        OnlineMusicController.onlineQueue
                                            .removeAt(index);
                                        OnlineMusicController
                                                .currentIndex
                                                .value =
                                            audioPlayer.currentIndex ?? -1;
                                      }
                                    }
                                  },
                                ),
                                const Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () {
                              if (isItemOnline) {
                                // Nếu là nhạc online, phải gọi playSong để lấy link thực
                                OnlineMusicController.playSong(
                                  index,
                                  audioPlayer,
                                  context,
                                  queueType: OnlineMusicController
                                      .currentQueueType
                                      .value,
                                );
                              } else {
                                audioPlayer.seek(Duration.zero, index: index);
                                audioPlayer.play();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

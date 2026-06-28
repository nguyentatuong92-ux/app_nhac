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
      backgroundColor: Theme.of(context).cardColor,
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
    final accentColor = Theme.of(context).colorScheme.primary;
    return StreamBuilder<SequenceState?>(
      stream: audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex ?? -1;

        final currentSource = state?.currentSource;
        final currentMediaItem = currentSource?.tag as MediaItem?;
        final isOnline = currentMediaItem?.extras?['is_online'] == true;

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOnline ? Icons.language : Icons.queue_music,
                      color: accentColor,
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
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: accentColor, height: 1),
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
                            await audioPlayer.moveAudioSource(
                              oldIndex,
                              newIndex,
                            );

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
                                          (context, error, stackTrace) => Icon(
                                            Icons.music_note,
                                            color: accentColor,
                                          ),
                                    )
                                  : QueryArtworkWidget(
                                      id: int.tryParse(itemMedia.id) ?? 0,
                                      type: ArtworkType.AUDIO,
                                      nullArtworkWidget: Icon(
                                        Icons.music_note,
                                        color: accentColor,
                                      ),
                                    ),
                            ),
                            title: Text(
                              itemMedia.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying
                                    ? accentColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
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
                                    ? accentColor
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPlaying)
                                  Icon(Icons.equalizer, color: accentColor),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.indigo,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    if (audioPlayer.sequence.length > index) {
                                      if (isOnline &&
                                          OnlineMusicController
                                                  .currentQueueType
                                                  .value ==
                                              "playlist") {
                                        await OnlineMusicController.syncRemoveFromPlaylist(
                                          itemMedia,
                                        );
                                      }

                                      await audioPlayer.removeAudioSourceAt(
                                        index,
                                      );

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

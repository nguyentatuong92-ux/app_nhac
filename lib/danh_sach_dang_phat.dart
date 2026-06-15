import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'online_music_controller.dart'; // THÊM IMPORT

class DanhSachDangPhat extends StatelessWidget {
  final AudioPlayer audioPlayer;

  const DanhSachDangPhat({super.key, required this.audioPlayer});

  // Hàm tĩnh (static) giúp gọi hiển thị bảng này một cách dễ dàng từ bất kỳ đâu
  static void show(BuildContext context, AudioPlayer audioPlayer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B), // Màu nền tối đồng nhất với app
      isScrollControlled: true, // Cho phép kéo bảng lên cao hơn
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DanhSachDangPhat(audioPlayer: audioPlayer),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Kiểm tra xem đang phát nhạc Online hay Offline
    final currentSource = audioPlayer.sequenceState?.currentSource;
    final mediaItem = currentSource?.tag as MediaItem?;
    final isOnline = mediaItem?.extras?['is_online'] == true;

    // Lấy danh sách các bài hát đang được nạp vào trình phát (Dùng cho Offline)
    final sequence = audioPlayer.sequence;

    return FractionallySizedBox(
      heightFactor: 0.6, // Bảng hiện lên chiếm 60% chiều cao màn hình
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
                  isOnline ? 'Kết quả tìm kiếm Online' : 'Danh sách phát',
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
            child: isOnline
                ? _buildOnlineList(context)
                : _buildOfflineList(sequence, audioPlayer),
          ),
        ],
      ),
    );
  }

  // GIAO DIỆN DANH SÁCH ONLINE
  Widget _buildOnlineList(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OnlineMusicController.currentIndex,
      builder: (context, currentIndex, child) {
        if (OnlineMusicController.searchResults.isEmpty) {
          return const Center(
            child: Text(
              "Không có danh sách tìm kiếm.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: OnlineMusicController.searchResults.length,
          itemBuilder: (context, index) {
            final video = OnlineMusicController.searchResults[index];
            final isPlaying = index == currentIndex;

            // Định dạng thời lượng
            String durationStr = "--:--";
            if (video.duration != null) {
              String minutes = video.duration!.inMinutes.toString().padLeft(
                2,
                '0',
              );
              String seconds = (video.duration!.inSeconds % 60)
                  .toString()
                  .padLeft(2, '0');
              durationStr = "$minutes:$seconds";
            }

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.thumbnails.mediumResUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.music_note, color: Colors.grey),
                ),
              ),
              title: Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.tealAccent : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                "${video.author} • $durationStr",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.tealAccent : Colors.grey[400],
                ),
              ),
              trailing: isPlaying
                  ? const Icon(Icons.equalizer, color: Colors.tealAccent)
                  : null,
              onTap: () {
                OnlineMusicController.playSong(index, audioPlayer, context);
              },
            );
          },
        );
      },
    );
  }

  // GIAO DIỆN DANH SÁCH OFFLINE (GIỮ NGUYÊN LOGIC CŨ)
  Widget _buildOfflineList(
    List<IndexedAudioSource>? sequence,
    AudioPlayer audioPlayer,
  ) {
    if (sequence == null || sequence.isEmpty) {
      return const Center(
        child: Text(
          'Không có bài hát nào trong hàng đợi.',
          style: TextStyle(color: Colors.tealAccent, fontSize: 18),
        ),
      );
    }

    return StreamBuilder<int?>(
      stream: audioPlayer.currentIndexStream,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data ?? 0;

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: sequence.length,
          onReorder: (int oldIndex, int newIndex) async {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            try {
              final audioSource =
                  audioPlayer.audioSource as ConcatenatingAudioSource?;
              if (audioSource != null) {
                await audioSource.move(oldIndex, newIndex);
              }
            } catch (e) {
              debugPrint("Lỗi di chuyển bài hát: $e");
            }
          },
          itemBuilder: (context, index) {
            final itemMedia = sequence[index].tag as MediaItem;
            final isPlaying = index == currentIndex;

            return ListTile(
              key: ValueKey(itemMedia.id + index.toString()),
              leading: Icon(
                isPlaying ? Icons.play_circle : Icons.music_note,
                color: isPlaying ? Colors.tealAccent : Colors.grey,
                size: isPlaying ? 30 : 24,
              ),
              title: Text(
                itemMedia.title,
                style: TextStyle(
                  color: isPlaying ? Colors.tealAccent : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                itemMedia.artist ?? 'Không biết',
                style: TextStyle(color: Colors.grey[400]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
              onTap: () {
                audioPlayer.seek(Duration.zero, index: index);
                audioPlayer.play();
              },
            );
          },
        );
      },
    );
  }
}

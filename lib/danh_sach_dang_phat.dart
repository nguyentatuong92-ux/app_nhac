import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
    // Lấy danh sách các bài hát đang được nạp vào trình phát
    final sequence = audioPlayer.sequence;

    if (sequence == null || sequence.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Không có bài hát nào trong hàng đợi.',
            style: TextStyle(color: Colors.tealAccent, fontSize: 18),
          ),
        ),
      );
    }

    return FractionallySizedBox(
      heightFactor: 0.6, // Bảng hiện lên chiếm 60% chiều cao màn hình
      child: Column(
        children: [
          // 1. Thanh Tiêu đề
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.queue_music, color: Colors.tealAccent, size: 28),
                SizedBox(width: 10),
                Text(
                  'Danh sách phát',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.tealAccent, height: 1),

          // 2. Danh sách bài hát (Dùng StreamBuilder để theo dõi bài đang hát)
          Expanded(
            child: StreamBuilder<int?>(
              stream: audioPlayer.currentIndexStream,
              builder: (context, snapshot) {
                final currentIndex = snapshot.data ?? 0;

                // THAY THẾ TOÀN BỘ BẰNG ĐOẠN MÃ NÀY
                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: sequence.length,
                  // 1. Hàm xử lý khi người dùng kéo thả
                  onReorder: (int oldIndex, int newIndex) async {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    try {
                      // Ra lệnh cho trình phát nhạc thay đổi thứ tự thực tế trong hàng đợi
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
                    final mediaItem = sequence[index].tag as MediaItem;
                    final isPlaying = index == currentIndex;

                    return ListTile(
                      // 2. BẮT BUỘC CÓ KEY ĐỂ FLUTTER NHẬN DIỆN KHI KÉO THẢ
                      key: ValueKey(mediaItem.id + index.toString()),

                      leading: Icon(
                        isPlaying ? Icons.play_circle : Icons.music_note,
                        color: isPlaying ? Colors.tealAccent : Colors.grey,
                        size: isPlaying ? 30 : 24,
                      ),
                      title: Text(
                        mediaItem.title,
                        style: TextStyle(
                          color: isPlaying ? Colors.tealAccent : Colors.white,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        mediaItem.artist ?? 'Không biết',
                        style: TextStyle(color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Thêm icon 3 gạch ở cuối để người dùng biết là có thể kéo thả
                      trailing: const Icon(
                        Icons.drag_handle,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        // Khi bấm vào bài nào, nhảy ngay đến bài đó và phát
                        audioPlayer.seek(Duration.zero, index: index);
                        audioPlayer.play();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

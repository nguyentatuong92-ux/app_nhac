// file: mini_player.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'home_screen.dart';
import 'online_music_controller.dart';

class MiniPlayer extends StatelessWidget {
  // GIỮ LẠI CHO NHẠC OFFLINE
  final SongModel? currentSong;

  // THÊM CÁC THAM SỐ CHO NHẠC ONLINE
  final bool isOnline;
  final String? onlineTitle;
  final String? onlineArtist;
  final String? onlineThumbUrl;

  final AudioPlayer audioPlayer;
  final VoidCallback onRefresh;

  const MiniPlayer({
    super.key,
    this.currentSong, // Chuyển thành có thể null
    this.isOnline = false, // Mặc định là offline
    this.onlineTitle,
    this.onlineArtist,
    this.onlineThumbUrl,
    required this.audioPlayer,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Dùng ValueListenableBuilder bọc bên ngoài cùng để lắng nghe sự thay đổi
    return ValueListenableBuilder<int>(
      valueListenable: OnlineMusicController.currentIndex,
      builder: (context, currentIndex, child) {
        // 2. TÍNH TOÁN LẠI TÊN BÀI VÀ CA SĨ BÊN TRONG NÀY
        // Xác định xem có phải đang phát nhạc online không
        final isOnlineNow =
            isOnline ||
            (currentIndex != -1 &&
                OnlineMusicController.searchResults.isNotEmpty);

        // Lấy thông tin video hiện tại nếu đang phát online
        final video =
            (isOnlineNow &&
                currentIndex >= 0 &&
                currentIndex < OnlineMusicController.searchResults.length)
            ? OnlineMusicController.searchResults[currentIndex]
            : null;

        // Cập nhật lại title và artist dựa theo nguồn nhạc
        final title = isOnlineNow && video != null
            ? video.title
            : (currentSong?.title ?? "Không rõ tên bài");

        final artist = isOnlineNow && video != null
            ? video.author
            : (currentSong?.artist ?? "Không biết");

        // 3. TRẢ VỀ GIAO DIỆN GESTURE DETECTOR (Giữ nguyên code cũ của bạn bên trong)
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(audioPlayer: audioPlayer),
              ),
            ).then((_) => onRefresh());
          },
          child: Container(
            height: 75,
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
                      // ẢNH BÌA SẼ ĐƯỢC CẬP NHẬT Ở HÀM _buildArtwork BÊN DƯỚI
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          color: const Color(0xFF4B5563),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildArtwork(),
                      ),
                      const SizedBox(width: 12),
                      // PHẦN CHỮ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextScroll(
                              title,
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
                              artist,
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
                          // SỬA Ở ĐÂY: Dùng isOnlineNow thay vì isOnline
                          if (isOnlineNow) {
                            OnlineMusicController.playPrevious(
                              audioPlayer,
                              context,
                            );
                          } else if (audioPlayer.hasPrevious) {
                            audioPlayer.seekToPrevious();
                          }
                        },
                      ),
                      // NÚT PLAY/PAUSE
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
                              isPlaying
                                  ? audioPlayer.pause()
                                  : audioPlayer.play();
                            },
                          );
                        },
                      ),
                      // NÚT QUA BÀI
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () {
                          // SỬA Ở ĐÂY: Dùng isOnlineNow thay vì isOnline
                          if (isOnlineNow) {
                            OnlineMusicController.playNext(
                              audioPlayer,
                              context,
                            );
                          } else if (audioPlayer.hasNext) {
                            audioPlayer.seekToNext();
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),

                // THANH TIẾN TRÌNH TUA NHẠC
                StreamBuilder<Duration>(
                  stream: audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = audioPlayer.duration ?? Duration.zero;

                    double progress = 0.0;
                    if (duration.inMilliseconds > 0) {
                      progress =
                          position.inMilliseconds / duration.inMilliseconds;
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) {
                            if (duration.inMilliseconds > 0) {
                              final tapPosition = details.localPosition.dx;
                              final percentage =
                                  tapPosition / constraints.maxWidth;
                              final seekPosition = Duration(
                                milliseconds:
                                    (duration.inMilliseconds * percentage)
                                        .round(),
                              );
                              audioPlayer.seek(seekPosition);
                            }
                          },
                          child: Container(
                            height: 12,
                            color: Colors.transparent,
                            alignment: Alignment.bottomCenter,
                            child: ClipRRect(
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
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Hàm phụ trợ để render ảnh cho gọn code
  Widget _buildArtwork() {
    // Lấy vị trí bài hát online đang phát
    final currentIndex = OnlineMusicController.currentIndex.value;

    // Nếu đang phát nhạc online và danh sách có bài hát
    if ((isOnline || currentIndex != -1) &&
        currentIndex >= 0 &&
        currentIndex < OnlineMusicController.searchResults.length) {
      final thumbUrl = OnlineMusicController
          .searchResults[currentIndex]
          .thumbnails
          .highResUrl;
      return Image.network(thumbUrl, fit: BoxFit.cover);
    }
    // Nếu phát nhạc offline
    else {
      if (currentSong != null) {
        return QueryArtworkWidget(
          id: currentSong!.id,
          type: ArtworkType.AUDIO,
          artworkFit: BoxFit.cover,
          nullArtworkWidget: const Icon(
            Icons.music_note,
            color: Colors.tealAccent,
          ),
        );
      }
      return const Icon(Icons.music_note, color: Colors.tealAccent);
    }
  }
}

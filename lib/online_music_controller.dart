import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class OnlineMusicController {
  static final YoutubeExplode yt = YoutubeExplode();

  // Lưu trữ danh sách bài hát tìm kiếm được và vị trí đang phát
  static List<Video> searchResults = [];
  // Dùng ValueNotifier để TabOnline tự động sáng màu bài đang hát
  static ValueNotifier<int> currentIndex = ValueNotifier<int>(-1);

  // Hàm phát nhạc
  static Future<void> playSong(
    int index,
    AudioPlayer audioPlayer,
    BuildContext context,
  ) async {
    if (index < 0 || index >= searchResults.length) return;

    currentIndex.value = index; // Cập nhật vị trí
    final video = searchResults[index];

    try {
      var manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: [
          YoutubeApiClient.androidVr,
          YoutubeApiClient.ios,
          YoutubeApiClient.safari,
        ],
      );

      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final audioSource = AudioSource.uri(
        audioStreamInfo.url,
        tag: MediaItem(
          id: video.id.value.hashCode.toString(), // Fix lỗi crash
          title: video.title,
          artist: video.author,
          artUri: Uri.parse(video.thumbnails.highResUrl),
          // CỰC KỲ QUAN TRỌNG: Gắn cờ để nhận diện đây là nhạc online!
          extras: {'is_online': true},
        ),
      );

      await audioPlayer.setAudioSource(audioSource);
      audioPlayer.play();
    } catch (e) {
      debugPrint("Lỗi khi lấy link nhạc: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể phát bài hát này. Vui lòng thử bài khác."),
          ),
        );
      }
    }
  }

  // Chuyển bài tiếp theo
  static Future<void> playNext(AudioPlayer player, BuildContext context) async {
    if (currentIndex.value < searchResults.length - 1) {
      await playSong(currentIndex.value + 1, player, context);
    }
  }

  // Quay lại bài trước
  static Future<void> playPrevious(
    AudioPlayer player,
    BuildContext context,
  ) async {
    if (currentIndex.value > 0) {
      await playSong(currentIndex.value - 1, player, context);
    }
  }
}

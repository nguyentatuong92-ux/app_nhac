import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async'; // Bắt buộc phải có để dùng StreamSubscription và Completer
import 'package:on_audio_query/on_audio_query.dart';

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

    // 1. HIỂN THỊ XOÁY TRÒN TẢI DỮ LIỆU
    showDialog(
      context: context,
      barrierDismissible:
          false, // Ngăn người dùng bấm ra ngoài để tắt màn hình tải
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      ),
    );

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
          id: video.id.value.hashCode.toString(),
          title: video.title,
          artist: video.author,
          artUri: Uri.parse(video.thumbnails.highResUrl),
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
    } finally {
      // 2. ĐÓNG XOÁY TRÒN KHI ĐÃ TẢI XONG (HOẶC BỊ LỖI)
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Hàm tải bài hát về máy (Có nút Tạm dừng / Hủy)
  static Future<void> downloadSong(Video video, BuildContext context) async {
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    StreamSubscription<List<int>>? subscription; // Bộ điều khiển tải
    IOSink? fileStream;
    File? file;

    bool isPaused = false;
    bool isCancelled = false;
    Completer<void> completer =
        Completer<void>(); // Giữ hàm chạy nền cho đến khi xong

    // 1. Hiển thị hộp thoại tải với StatefulBuilder để cập nhật nút bấm
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            content: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, progress, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPaused
                          ? "Tạm dừng: ${video.title}"
                          : "Đang tải: ${video.title}",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[700],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPaused
                              ? Colors.orangeAccent
                              : Colors.tealAccent, // Đổi màu khi tạm dừng
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: isPaused
                            ? Colors.orangeAccent
                            : Colors.tealAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              // NÚT HỦY
              TextButton(
                onPressed: () async {
                  isCancelled = true;
                  subscription?.cancel(); // Hủy tải
                  await fileStream?.close();
                  if (file != null && await file!.exists()) {
                    await file!.delete(); // Xóa file đang tải dở để dọn rác
                  }
                  if (context.mounted) Navigator.pop(context); // Đóng hộp thoại
                  if (!completer.isCompleted) completer.complete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đã hủy tải bài hát!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text(
                  "Hủy",
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
              // NÚT TẠM DỪNG / TIẾP TỤC
              TextButton(
                onPressed: () {
                  if (isPaused) {
                    subscription?.resume(); // Tiếp tục tải
                    setStateDialog(() => isPaused = false);
                  } else {
                    subscription?.pause(); // Tạm dừng
                    setStateDialog(() => isPaused = true);
                  }
                },
                child: Text(
                  isPaused ? "Tiếp tục" : "Tạm dừng",
                  style: TextStyle(
                    color: isPaused ? Colors.tealAccent : Colors.orangeAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      // 2. Lấy thông tin âm thanh từ YouTube
      var manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: [
          YoutubeApiClient.androidVr,
          YoutubeApiClient.ios,
          YoutubeApiClient.safari,
        ],
      );
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      var audioStream = yt.videos.streamsClient.get(audioStreamInfo);
      var totalBytes = audioStreamInfo.size.totalBytes;

      // 3. Tìm thư mục lưu trữ
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists())
          directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // 4. Mở file để ghi
      String safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      file = File('${directory?.path}/$safeTitle.m4a');
      fileStream = file.openWrite();

      // 5. Ghi dữ liệu bằng luồng (Stream Lắng nghe)
      int downloadedBytes = 0;
      subscription = audioStream.listen(
        (data) {
          downloadedBytes += data.length;
          fileStream!.add(data); // Ghi dữ liệu vào máy
          if (totalBytes > 0) {
            progressNotifier.value = downloadedBytes / totalBytes;
          }
        },
        onDone: () async {
          if (isCancelled) return; // Bỏ qua nếu người dùng đã hủy
          await fileStream!.flush();
          await fileStream!.close();

          // --- MỚI THÊM: BÁO CHO ANDROID BIẾT CÓ FILE MỚI ĐỂ CẬP NHẬT ---
          try {
            if (Platform.isAndroid && file != null) {
              await OnAudioQuery().scanMedia(file!.path);
            }
          } catch (e) {
            debugPrint("Lỗi quét media: $e");
          }
          if (context.mounted) {
            Navigator.pop(context); // Tắt hộp thoại
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Đã tải xong: $safeTitle"),
                backgroundColor: Colors.lightBlue,
                behavior: SnackBarBehavior
                    .floating, // Giúp SnackBar nổi lên khỏi viền dưới
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    15.0,
                  ), // Điều chỉnh độ bo góc tại đây
                ),
              ),
            );
          }
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) async {
          if (isCancelled) return;
          await fileStream!.close();
          if (file != null && await file!.exists())
            await file!.delete(); // Xóa file lỗi

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Lỗi khi tải bài hát!"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior
                    .floating, // Giúp SnackBar nổi lên khỏi viền dưới
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    15.0,
                  ), // Điều chỉnh độ bo góc tại đây
                ),
              ),
            );
          }
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      // Lệnh này giúp hàm không bị kết thúc cho đến khi tải xong hoặc bị hủy
      await completer.future;
    } catch (e) {
      debugPrint("Lỗi tải nhạc: $e");
      if (!isCancelled && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Không thể tải bài hát!"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior
                .floating, // Giúp SnackBar nổi lên khỏi viền dưới
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15.0,
              ), // Điều chỉnh độ bo góc tại đây
            ),
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

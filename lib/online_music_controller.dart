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

  // BIẾN ĐỂ KIỂM SOÁT VIỆC TỰ ĐỘNG LẤY LINK KHI QUA BÀI
  static StreamSubscription? _positionSubscription;

  // Hàm phát nhạc
  static Future<void> playSong(
    int index,
    AudioPlayer audioPlayer,
    BuildContext context, {
    bool showLoading = true, // Thêm tham số để ẩn/hiện xoáy tròn
  }) async {
    if (index < 0 || index >= searchResults.length) return;

    // 1. HIỂN THỊ XOÁY TRÒN TẢI DỮ LIỆU (Nếu yêu cầu)
    if (showLoading && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    currentIndex.value = index;
    final video = searchResults[index];

    try {
      // Lấy link nhạc thật từ YouTube
      var manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: [YoutubeApiClient.androidVr],
      );
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      // TẠO DANH SÁCH PHÁT (CONCATENATING) ĐỂ HIỆN NÚT TRÊN MÀN HÌNH KHÓA
      List<AudioSource> sources = [];
      for (int i = 0; i < searchResults.length; i++) {
        final v = searchResults[i];

        if (i == index) {
          // Bài hiện tại: Dùng link thật
          sources.add(
            AudioSource.uri(
              audioStreamInfo.url,
              tag: MediaItem(
                id: v.id.value,
                title: v.title,
                artist: v.author,
                duration: v.duration,
                artUri: Uri.parse(v.thumbnails.highResUrl),
                extras: {'is_online': true, 'index': i},
              ),
            ),
          );
        } else {
          // Các bài khác: Dùng link "chờ" (Phải khác nhau URI để không bị cache lỗi)
          sources.add(
            AudioSource.uri(
              Uri.parse("https://example.com/placeholder_${i}.mp3"),
              tag: MediaItem(
                id: v.id.value,
                title: v.title,
                artist: v.author,
                duration: v.duration,
                artUri: Uri.parse(v.thumbnails.highResUrl),
                extras: {'is_online': true, 'index': i},
              ),
            ),
          );
        }
      }

      final playlist = ConcatenatingAudioSource(children: sources);

      // Nạp danh sách vào Player và nhảy đến đúng bài
      await audioPlayer.setAudioSource(playlist, initialIndex: index);
      audioPlayer.play();

      // THIẾT LẬP TỰ ĐỘNG CẬP NHẬT LINK KHI NGƯỜI DÙNG BẤM NEXT TRÊN MÀN HÌNH KHÓA
      _setupLockScreenListener(audioPlayer, context);
    } catch (e) {
      debugPrint("Lỗi khi lấy link nhạc: $e");
      // CHỈ HIỆN THÔNG BÁO LỖI NẾU KHÔNG PHẢI LÀ LỖI DO CHUYỂN BÀI NGẦM
      if (showLoading && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi: Không thể tải bài hát này.")),
        );
      }
    } finally {
      // Đóng xoáy tròn nếu đang hiển thị
      if (showLoading && context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  // HÀM LẮNG NGHE KHI NGƯỜI DÙNG BẤM NEXT/PREV TRÊN MÀN HÌNH KHÓA
  static void _setupLockScreenListener(
    AudioPlayer player,
    BuildContext context,
  ) {
    _positionSubscription?.cancel();
    _positionSubscription = player.currentIndexStream.listen((index) async {
      // 1. Chỉ xử lý nếu index thay đổi sang một bài mới
      if (index == null || index == currentIndex.value) return;

      // 2. QUAN TRỌNG: Kiểm tra xem nguồn nhạc HIỆN TẠI có phải là Online không
      // Nếu người dùng đã chuyển sang nghe nhạc Offline, ta phải dừng việc lấy link YouTube
      final currentSource = player.sequenceState?.currentSource;
      final mediaItem = currentSource?.tag as MediaItem?;
      final isOnlineMedia = mediaItem?.extras?['is_online'] == true;

      if (!isOnlineMedia) {
        // Nếu không phải nhạc Online, cập nhật currentIndex về -1 và thoát
        currentIndex.value = -1;
        return;
      }

      // 3. KIỂM TRA BÀI MỚI CÓ PHẢI LÀ LINK CHỜ (PLACEHOLDER) KHÔNG
      // Chỉ lấy link thật nếu bài hiện tại đang là placeholder
      final uriStr = (currentSource as UriAudioSource?)?.uri.toString() ?? "";
      final isPlaceholder = uriStr.contains("example.com/placeholder");

      if (isPlaceholder && context.mounted) {
        // Cập nhật currentIndex để đồng bộ UI
        currentIndex.value = index;

        // Gọi playSong để lấy link thật
        // Bật lại showLoading: true để hiển thị xoáy tròn khi chuyển bài
        playSong(index, player, context, showLoading: true);
      } else {
        // Nếu đã là link thật rồi thì chỉ cập nhật vị trí sáng màu trên UI
        currentIndex.value = index;
      }
    });
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
                              ? Colors.teal
                              : Colors.tealAccent, // Đổi màu khi tạm dừng
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: isPaused ? Colors.teal : Colors.tealAccent,
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
                  if (file != null && await file.exists()) {
                    await file.delete(); // Xóa file đang tải dở để dọn rác
                  }
                  if (dialogContext.mounted)
                    Navigator.pop(dialogContext); // Đóng hộp thoại
                  if (!completer.isCompleted) completer.complete();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF64B5F6),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15.0)),
                        ),
                        content: Text(
                          "Đã hủy tải bài hát!",
                          style: TextStyle(color: Colors.black54, fontSize: 22),
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  "Hủy",
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
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
                    color: isPaused ? Colors.tealAccent : Colors.blueGrey,
                    fontSize: 22,
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
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
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
                content: Text(
                  "Đã tải xong: $safeTitle",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 22),
                ),
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
      // Vì đã có hàng đợi, ta chỉ cần gọi seekToNext, bộ lắng nghe sẽ tự lấy link thật
      player.seekToNext();
    }
  }

  // Quay lại bài trước
  static Future<void> playPrevious(
    AudioPlayer player,
    BuildContext context,
  ) async {
    if (currentIndex.value > 0) {
      player.seekToPrevious();
    }
  }

  // Ghi chú: Đã gỡ bỏ setupAutoNext cũ vì dùng cơ chế hàng đợi ConcatenatingAudioSource
  // của just_audio kết hợp với _setupLockScreenListener giúp chuyển bài tự động mượt mà hơn.
}

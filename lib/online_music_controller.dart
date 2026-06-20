import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';

class OnlineMusicController {
  static final YoutubeExplode yt = YoutubeExplode();

  static List<Video> searchResults = [];
  static List<Video> onlinePlaylist = [];
  static List<Video> onlineQueue = [];

  static ValueNotifier<int> currentIndex = ValueNotifier<int>(-1);
  static ValueNotifier<String> currentQueueType = ValueNotifier<String>("");

  static StreamSubscription? _positionSubscription;
  static StreamSubscription? _playerStateSubscription;
  static bool _isProcessing = false;

  static void _setupLockScreenListener(
    AudioPlayer player,
    BuildContext context,
  ) {
    _positionSubscription?.cancel();
    _positionSubscription = player.currentIndexStream.listen((index) async {
      if (index == null || index == currentIndex.value) return;

      final sequence = player.sequence;
      if (index >= sequence.length) return;

      final currentSource = sequence[index];
      final mediaItem = currentSource.tag as MediaItem?;
      final isOnlineMedia = mediaItem?.extras?['is_online'] == true;

      if (!isOnlineMedia) {
        currentIndex.value = -1;
        return;
      }

      final uriStr = (currentSource as UriAudioSource?)?.uri.toString() ?? "";
      final isPlaceholder = uriStr.contains("example.com/placeholder");

      if (isPlaceholder && context.mounted) {
        currentIndex.value = index;
        Future.microtask(() {
          if (context.mounted) {
            playSong(
              index,
              player,
              context,
              showLoading: false,
              queueType: currentQueueType.value,
            );
          }
        });
      } else {
        currentIndex.value = index;
      }
    });

    _playerStateSubscription?.cancel();
    _playerStateSubscription = player.playerStateStream.listen((state) {
      // Khi một bài hát hát xong, just_audio tự động chuyển sang index tiếp theo.
      // Nếu bài tiếp theo là placeholder, listener ở currentIndexStream bên trên sẽ lo việc tải nhạc.
      // Tuy nhiên, nếu bài hát cuối cùng kết thúc và có chế độ lặp lại (LoopMode.all),
      // ta cũng cần đảm bảo bài đầu tiên được nạp lại link thật.
      if (state.processingState == ProcessingState.completed) {
        if (player.loopMode == LoopMode.all && onlineQueue.isNotEmpty) {
          playSong(
            0,
            player,
            context,
            showLoading: false,
            queueType: currentQueueType.value,
          );
        }
      }
    });
  }

  static Future<void> playSong(
    int index,
    AudioPlayer audioPlayer,
    BuildContext context, {
    bool showLoading = true,
    List<Video>? customQueue,
    String queueType = "search",
  }) async {
    List<Video> queue =
        customQueue ??
        (currentQueueType.value == queueType ? onlineQueue : searchResults);

    if (index < 0 || index >= queue.length) return;
    if (_isProcessing) return;

    _isProcessing = true;
    bool dialogOpened = false;

    if (showLoading && context.mounted) {
      dialogOpened = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.tealAccent),
          );
        },
      );
    }

    currentIndex.value = index;
    final video = queue[index];
    onlineQueue = List.from(queue);

    try {
      var manifest = await yt.videos.streamsClient
          .getManifest(video.id, ytClients: [YoutubeApiClient.androidVr])
          .timeout(const Duration(seconds: 15));

      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final realSource = AudioSource.uri(
        audioStreamInfo.url,
        tag: MediaItem(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          duration: video.duration,
          artUri: Uri.parse(video.thumbnails.highResUrl),
          extras: {'is_online': true, 'index': index},
        ),
      );

      final currentPlaylist =
          audioPlayer.audioSource as ConcatenatingAudioSource?;

      bool isSameQueue =
          currentQueueType.value == queueType &&
          currentPlaylist != null &&
          currentPlaylist.length == onlineQueue.length;

      if (isSameQueue) {
        // Chỉ cập nhật bài hát tại vị trí index nếu đã có danh sách
        await currentPlaylist.removeAt(index);
        await currentPlaylist.insert(index, realSource);

        // Nếu trình phát chưa ở đúng index thì nhảy tới
        if (audioPlayer.currentIndex != index) {
          await audioPlayer.seek(Duration.zero, index: index);
        }
      } else {
        // Nếu danh sách mới hoặc khác loại thì nạp lại toàn bộ
        currentQueueType.value = queueType;
        List<AudioSource> sources = [];
        for (int i = 0; i < onlineQueue.length; i++) {
          final v = onlineQueue[i];
          if (i == index) {
            sources.add(realSource);
          } else {
            sources.add(
              AudioSource.uri(
                Uri.parse("https://example.com/placeholder_${v.id.value}.mp3"),
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
        await audioPlayer.setAudioSource(
          playlist,
          initialIndex: index,
          preload: true,
        );
      }

      // Đóng dialog ngay khi nạp xong dữ liệu (không đợi play() xong)
      if (dialogOpened && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpened = false;
      }

      _setupLockScreenListener(audioPlayer, context);
      await audioPlayer.play();
    } catch (e) {
      debugPrint("Lỗi khi lấy link nhạc: $e");
    } finally {
      _isProcessing = false;
      if (dialogOpened && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  static Future<void> downloadSong(Video video, BuildContext context) async {
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    StreamSubscription<List<int>>? subscription;
    IOSink? fileStream;
    File? file;

    bool isPaused = false;
    bool isCancelled = false;
    Completer<void> completer = Completer<void>();

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
                          isPaused ? Colors.teal : Colors.tealAccent,
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
              TextButton(
                onPressed: () async {
                  isCancelled = true;
                  subscription?.cancel();
                  await fileStream?.close();
                  if (file != null && await file.exists()) {
                    await file.delete();
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                          style: TextStyle(color: Colors.white, fontSize: 22),
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
              TextButton(
                onPressed: () {
                  if (isPaused) {
                    subscription?.resume();
                    isPaused = false;
                    setStateDialog(() {});
                  } else {
                    subscription?.pause();
                    isPaused = true;
                    setStateDialog(() {});
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

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      file = File('${directory?.path}/$safeTitle.m4a');
      fileStream = file.openWrite();

      int downloadedBytes = 0;
      subscription = audioStream.listen(
        (data) {
          downloadedBytes += data.length;
          fileStream!.add(data);
          if (totalBytes > 0) {
            progressNotifier.value = downloadedBytes / totalBytes;
          }
        },
        onDone: () async {
          if (isCancelled) return;
          await fileStream!.flush();
          await fileStream!.close();

          try {
            if (Platform.isAndroid && file != null) {
              await OnAudioQuery().scanMedia(file!.path);
            }
          } catch (e) {
            debugPrint("Lỗi quét media: $e");
          }
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Đã tải xong: $safeTitle",
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
                backgroundColor: Colors.lightBlue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
            );
          }
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) async {
          if (isCancelled) return;
          await fileStream!.close();
          if (file != null && await file!.exists()) await file!.delete();

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Lỗi khi tải bài hát!"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15.0)),
                ),
              ),
            );
          }
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      debugPrint("Lỗi tải nhạc: $e");
      if (!isCancelled && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể tải bài hát!"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15.0)),
            ),
          ),
        );
      }
    }
  }

  static void addToOnlinePlaylist(
    Video video,
    BuildContext context,
    AudioPlayer audioPlayer,
  ) {
    bool exists = onlinePlaylist.any((v) => v.id.value == video.id.value);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF64B5F6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          content: Text("Bài hát đã có trong danh sách Online!"),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    onlinePlaylist.add(video);

    // --- MỚI THÊM: ĐỒNG BỘ VÀO HÀNG ĐỢI ĐANG PHÁT ---
    if (currentQueueType.value == "playlist") {
      final playlist = audioPlayer.audioSource as ConcatenatingAudioSource?;
      if (playlist != null) {
        onlineQueue.add(video);
        final index = onlineQueue.length - 1;
        final source = AudioSource.uri(
          Uri.parse("https://example.com/placeholder_${video.id.value}.mp3"),
          tag: MediaItem(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            duration: video.duration,
            artUri: Uri.parse(video.thumbnails.highResUrl),
            extras: {'is_online': true, 'index': index},
          ),
        );
        playlist.add(source);
      }
    }
    // -----------------------------------------------

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF64B5F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            15.0,
          ), // Điều chỉnh độ bo góc tại đây
        ),
        content: Text("Đã thêm vào danh sách Online!"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  static Future<void> removeFromOnlinePlaylist(int index) async {
    if (index >= 0 && index < onlinePlaylist.length) {
      onlinePlaylist.removeAt(index);
    }
  }

  // --- MỚI THÊM: Đồng bộ xóa từ Playlist lưu trữ vào Queue đang phát ---
  static Future<void> removeFromSavedAndActiveQueue(
    int index,
    AudioPlayer player,
  ) async {
    if (index < 0 || index >= onlinePlaylist.length) return;

    final videoToRemove = onlinePlaylist[index];
    onlinePlaylist.removeAt(index);

    // Nếu đang phát từ playlist, ta cần xóa bài hát này khỏi hàng đợi thực tế của trình phát
    if (currentQueueType.value == "playlist") {
      final playlist = player.audioSource as ConcatenatingAudioSource?;
      if (playlist != null) {
        // Tìm vị trí của bài hát trong onlineQueue (hàng đợi thực tế của player)
        int queueIndex = onlineQueue.indexWhere(
          (v) => v.id.value == videoToRemove.id.value,
        );
        if (queueIndex != -1 && queueIndex < playlist.length) {
          onlineQueue.removeAt(queueIndex);
          await playlist.removeAt(queueIndex);
          currentIndex.value = player.currentIndex ?? -1;
        }
      }
    }
  }

  // --- MỚI THÊM: Đồng bộ khi xóa từ Queue đang phát vào Playlist lưu trữ ---
  static Future<void> syncRemoveFromPlaylist(MediaItem item) async {
    // Tìm và xóa bài hát trong danh sách lưu trữ dựa trên ID (video.id.value)
    onlinePlaylist.removeWhere((v) => v.id.value == item.id);
  }

  // --- MỚI THÊM: Đồng bộ đổi thứ tự từ Playlist lưu trữ vào Queue đang phát ---
  static Future<void> reorderInSavedAndActiveQueue(
    int oldIndex,
    int newIndex,
    AudioPlayer player,
  ) async {
    if (oldIndex < newIndex) newIndex -= 1;

    final video = onlinePlaylist.removeAt(oldIndex);
    onlinePlaylist.insert(newIndex, video);

    // Nếu đang phát từ playlist, đồng bộ luôn thứ tự vào trình phát
    if (currentQueueType.value == "playlist") {
      final playlist = player.audioSource as ConcatenatingAudioSource?;
      if (playlist != null) {
        // Tìm vị trí thực tế trong hàng đợi đang phát
        int qOld = onlineQueue.indexWhere((v) => v.id.value == video.id.value);
        // Vì đây là reorder đồng bộ 1-1 từ playlist sang queue,
        // ta có thể giả định thứ tự là giống nhau hoặc thực hiện move phức tạp hơn.
        // Đơn giản nhất là move theo index mới trong playlist nếu onlineQueue cũng là bản sao 1-1.
        if (qOld != -1) {
          final qVideo = onlineQueue.removeAt(qOld);
          onlineQueue.insert(newIndex, qVideo);
          await playlist.move(qOld, newIndex);
          currentIndex.value = player.currentIndex ?? -1;
        }
      }
    }
  }

  static Future<void> playNext(AudioPlayer player, BuildContext context) async {
    if (currentIndex.value < onlineQueue.length - 1) {
      player.seekToNext();
    }
  }

  static Future<void> playPrevious(
    AudioPlayer player,
    BuildContext context,
  ) async {
    if (currentIndex.value > 0) {
      player.seekToPrevious();
    }
  }

  static Future<void> addToQueue(Video video, AudioPlayer audioPlayer) async {
    final playlist = audioPlayer.audioSource as ConcatenatingAudioSource?;
    if (playlist == null) return;

    onlineQueue.add(video);

    final index = onlineQueue.length - 1;
    final source = AudioSource.uri(
      Uri.parse("https://example.com/placeholder_${video.id.value}.mp3"),
      tag: MediaItem(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        artUri: Uri.parse(video.thumbnails.highResUrl),
        extras: {'is_online': true, 'index': index},
      ),
    );

    await playlist.add(source);
  }

  static Future<void> moveInQueue(
    int oldIndex,
    int newIndex,
    AudioPlayer audioPlayer,
  ) async {
    final playlist = audioPlayer.audioSource as ConcatenatingAudioSource?;
    if (playlist == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final video = onlineQueue.removeAt(oldIndex);
    onlineQueue.insert(newIndex, video);

    await playlist.move(oldIndex, newIndex);
  }

  static Future<void> removeFromQueue(
    int index,
    AudioPlayer audioPlayer,
  ) async {
    final playlist = audioPlayer.audioSource as ConcatenatingAudioSource?;
    if (playlist == null) return;

    onlineQueue.removeAt(index);
    await playlist.removeAt(index);
  }
}

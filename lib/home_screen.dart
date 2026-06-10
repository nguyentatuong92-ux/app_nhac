import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'; // Đã thêm để nhận diện MediaItem
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:volume_controller/volume_controller.dart';
import 'danh_sach_dang_phat.dart';

class HomeScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;

  const HomeScreen({super.key, required this.audioPlayer});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showVolumeSlider = false;

  // SỬA LỖI: Đổi SongModel thành MediaItem
  MediaItem? currentItem;
  Timer? _sleepTimer;

  double _currentVolume = 0.5;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  Uint8List? _artworkBytes;
  int? _currentArtworkId;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void initState() {
    super.initState();

    // SỬA LỖI: Lấy dữ liệu dưới dạng MediaItem thay vì SongModel
    currentItem =
        widget.audioPlayer.sequenceState?.currentSource?.tag as MediaItem?;
    if (currentItem != null) {
      // Vì id của MediaItem là dạng String, ta cần chuyển thành int để lấy ảnh bìa
      _fetchArtwork(int.parse(currentItem!.id));
    }

    widget.audioPlayer.sequenceStateStream.listen((state) {
      if (state != null && mounted) {
        final newItem = state.currentSource?.tag as MediaItem?;
        setState(() => currentItem = newItem);
        if (newItem != null) {
          _fetchArtwork(int.parse(newItem.id));
        }
      }
    });

    // ĐÃ SỬA: Lắng nghe toàn bộ trạng thái của trình phát
    widget.audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Chỉ hiện nút Pause khi đang play VÀ chưa chạy hết bài cuối
          isPlaying =
              state.playing &&
              state.processingState != ProcessingState.completed;
        });
      }
    });
    widget.audioPlayer.durationStream.listen(
      (d) => setState(() => _duration = d ?? Duration.zero),
    );
    widget.audioPlayer.positionStream.listen(
      (p) => setState(() => _position = p),
    );

    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((volume) {
      if (mounted) setState(() => _currentVolume = volume);
    });
    VolumeController.instance.addListener((volume) {
      if (mounted) setState(() => _currentVolume = volume);
    });
  }

  Future<void> _fetchArtwork(int songId) async {
    if (_currentArtworkId == songId) return;
    try {
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: 500,
      );

      if (mounted) {
        setState(() {
          _artworkBytes = bytes;
          _currentArtworkId = songId;
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy ảnh bìa: $e");
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã tắt hẹn giờ!',
            style: TextStyle(color: Colors.tealAccent, fontSize: 20),
          ),
        ),
      );
      return;
    }
    _sleepTimer = Timer(
      Duration(minutes: minutes),
      () => widget.audioPlayer.pause(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nhạc sẽ tự tắt sau $minutes phút nữa!',
          style: TextStyle(color: Colors.tealAccent, fontSize: 18),
        ),
      ),
    );
  }

  void _showCustomTimerDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        title: const Text(
          'Nhập thời gian (Phút)',
          style: TextStyle(color: Colors.tealAccent),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Colors.lime, fontSize: 20),
            ),
          ),
          TextButton(
            onPressed: () {
              int? m = int.tryParse(controller.text);
              if (m != null && m > 0) {
                Navigator.pop(context);
                _setSleepTimer(m);
              }
            },
            child: const Text(
              'Đồng ý',
              style: TextStyle(color: Colors.tealAccent, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF2A2A3A),
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                title: const Text(
                  "15 Phút",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _setSleepTimer(15);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                title: const Text(
                  "30 Phút",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _setSleepTimer(30);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                title: const Text(
                  "50 Phút",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _setSleepTimer(50);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                title: const Text(
                  "Tùy chỉnh...",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _showCustomTimerDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.timer_off_outlined,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                title: const Text(
                  "Tắt hẹn giờ",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _setSleepTimer(0);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double artworkSize = (screenWidth * 0.75).clamp(200.0, 350.0);

    return Scaffold(
      backgroundColor: const Color(0x901E293B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Tá Tưởng',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_left_sharp,
            color: Colors.tealAccent,
          ),
          iconSize: 50,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer, color: Colors.tealAccent, size: 38),
            onPressed: _showSleepTimerBottomSheet,
          ),
          IconButton(
            icon: Icon(
              _showVolumeSlider ? Icons.volume_up : Icons.volume_down,
              color: Colors.tealAccent,
              size: 38,
            ),
            onPressed: () =>
                setState(() => _showVolumeSlider = !_showVolumeSlider),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              if (_showVolumeSlider)
                Slider(
                  activeColor: Colors.tealAccent,
                  inactiveColor: Colors.grey[800],
                  value: _currentVolume,
                  onChanged: (v) {
                    setState(() => _currentVolume = v);
                    VolumeController.instance.setVolume(v);
                  },
                ),
              const Spacer(),

              Container(
                width: artworkSize,
                height: artworkSize,
                decoration: BoxDecoration(
                  color: Color(0xFF4B5563),
                  borderRadius: BorderRadius.circular(artworkSize / 2),
                  border: Border.all(color: Colors.tealAccent, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(artworkSize / 2),
                  child: (_artworkBytes != null && _artworkBytes!.isNotEmpty)
                      ? Image.memory(
                          _artworkBytes!,
                          width: artworkSize,
                          height: artworkSize,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Colors.tealAccent,
                        ),
                ),
              ),

              const SizedBox(height: 20),
              // Cập nhật lấy tên bài hát từ biến currentItem
              TextScroll(
                currentItem?.title ?? "Đang phát",
                style: const TextStyle(color: Colors.tealAccent, fontSize: 24),
              ),
              const Spacer(),
              // NÚT CHẾ ĐỘ PHÁT (ĐẶT Ở GIỮA)
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround, // Căn giữa nút
                children: [
                  // NÚT DANH SÁCH ĐANG PHÁT MỚI THÊM
                  IconButton(
                    icon: const Icon(
                      Icons.queue_music,
                      color: Colors.tealAccent,
                      size: 30,
                    ),
                    onPressed: () {
                      // Gọi hàm tĩnh từ tệp mới để hiển thị bảng
                      DanhSachDangPhat.show(context, widget.audioPlayer);
                    },
                  ),
                  StreamBuilder<LoopMode>(
                    stream: widget.audioPlayer.loopModeStream,
                    builder: (context, snapshot) {
                      final loopMode = snapshot.data ?? LoopMode.off;

                      Icon icon;
                      if (loopMode == LoopMode.off) {
                        icon = const Icon(
                          Icons.repeat,
                          color: Colors.grey,
                          size: 30,
                        );
                      } else if (loopMode == LoopMode.all) {
                        icon = const Icon(
                          Icons.repeat,
                          color: Colors.tealAccent,
                          size: 30,
                        );
                      } else {
                        icon = const Icon(
                          Icons.repeat_one,
                          color: Colors.tealAccent,
                          size: 30,
                        );
                      }

                      return IconButton(
                        icon: icon,
                        onPressed: () {
                          String thongBao = "";

                          if (loopMode == LoopMode.off) {
                            widget.audioPlayer.setLoopMode(LoopMode.all);
                            thongBao = "Đã bật: Lặp toàn bộ danh sách";
                          } else if (loopMode == LoopMode.all) {
                            widget.audioPlayer.setLoopMode(LoopMode.one);
                            thongBao = "Đã bật: Lặp 1 bài hiện tại";
                          } else {
                            widget.audioPlayer.setLoopMode(LoopMode.off);
                            thongBao = "Đã tắt: Phát theo danh sách";
                          }

                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              // Làm nền trong suốt và xóa đổ bóng
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.only(bottom: 230),
                              content: Text(
                                thongBao,
                                style: const TextStyle(
                                  color: Colors
                                      .tealAccent, // Đổi màu chữ cho hợp theme
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              duration: const Duration(milliseconds: 1500),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Kết thúc phần nút lặp lại
              Column(
                children: [
                  Slider(
                    activeColor: Colors.tealAccent,
                    inactiveColor: Colors.grey[800],
                    value: _position.inSeconds.toDouble().clamp(
                      0.0,
                      _duration.inSeconds.toDouble(),
                    ),
                    max: _duration.inSeconds.toDouble(),
                    onChanged: (v) =>
                        widget.audioPlayer.seek(Duration(seconds: v.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      size: 50,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () => widget.audioPlayer.seekToPrevious(),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.tealAccent,
                      size: 70,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        widget.audioPlayer.pause();
                      } else {
                        // Nếu đã hát hết danh sách (completed), tua lại bài đầu tiên rồi mới phát
                        if (widget.audioPlayer.processingState ==
                            ProcessingState.completed) {
                          widget.audioPlayer.seek(Duration.zero, index: 0);
                        }
                        widget.audioPlayer.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      size: 50,
                      color: Colors.tealAccent,
                    ),
                    onPressed: () => widget.audioPlayer.seekToNext(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

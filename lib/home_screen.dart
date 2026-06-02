// trang chủ
import 'dart:async';
import 'dart:typed_data'; // Đã thêm import này để dùng Uint8List
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:volume_controller/volume_controller.dart';

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
  SongModel? currentSong;
  Timer? _sleepTimer;

  double _currentVolume = 0.5; // Biến mới để lưu âm lượng thật của máy
  // --- CÁC BIẾN MỚI ĐỂ XỬ LÝ ẢNH BÌA ---
  final OnAudioQuery _audioQuery = OnAudioQuery();
  Uint8List? _artworkBytes;
  int? _currentArtworkId;
  // Hàm chuyển đổi Duration thành chuỗi hiển thị MM:SS
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
    currentSong =
        widget.audioPlayer.sequenceState?.currentSource?.tag as SongModel?;
    // Lấy ảnh ngay khi màn hình vừa mở (nếu có bài hát)
    if (currentSong != null) {
      _fetchArtwork(currentSong!.id);
    }
    widget.audioPlayer.sequenceStateStream.listen((state) {
      if (state != null && mounted) {
        final newSong = state.currentSource?.tag as SongModel?;
        setState(() => currentSong = newSong);

        // Cập nhật lại ảnh khi chuyển bài hát mới
        if (newSong != null) {
          _fetchArtwork(newSong.id);
        }
      }
    });

    widget.audioPlayer.playingStream.listen((playing) {
      if (mounted) setState(() => isPlaying = playing);
    });
    widget.audioPlayer.durationStream.listen(
      (d) => setState(() => _duration = d ?? Duration.zero),
    );
    widget.audioPlayer.positionStream.listen(
      (p) => setState(() => _position = p),
    );
    // 1. Tắt thanh UI âm lượng mặc định của máy
    VolumeController.instance.showSystemUI = false;
    // 2. Lấy âm lượng hiện tại khi vừa mở app
    VolumeController.instance.getVolume().then((volume) {
      if (mounted) setState(() => _currentVolume = volume);
    });
    // 3. Lắng nghe khi người dùng bấm nút cứng bên hông máy (đổi thành addListener)
    VolumeController.instance.addListener((volume) {
      if (mounted) setState(() => _currentVolume = volume);
    });
  }

  // --- HÀM TỰ LẤY ẢNH VÀ LƯU VÀO BIẾN ---
  Future<void> _fetchArtwork(int songId) async {
    // Tránh việc lấy lại ảnh nếu id bài hát không đổi
    if (_currentArtworkId == songId) return;
    try {
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: 500, // Tăng chất lượng ảnh lên một chút (tùy chọn)
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
        // <--- BỌC THÊM SAFEAREA VÀO ĐÂY NỮA
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
    // Lấy kích thước màn hình hiện tại của điện thoại
    final screenWidth = MediaQuery.of(context).size.width;
    // Đặt kích thước đĩa nhạc bằng 75% chiều rộng màn hình (tối đa 350 để không quá to trên tablet)
    final double artworkSize = (screenWidth * 0.75).clamp(200.0, 350.0);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,

        title: const Text(
          'Nguyễn Tá Tưởng',
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
        // <--- BỌC THÊM SAFEAREA Ở ĐÂY
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
                    // Gọi lệnh setVolume của phiên bản mới
                    VolumeController.instance.setVolume(v);
                  },
                ),
              const Spacer(),

              // ---  ẢNH BÌA BÀI HÁT ---
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(1000), // Bo tròn viền
                  border: Border.all(color: Colors.tealAccent, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1000),
                  child: (_artworkBytes != null)
                      ? Image.memory(
                          _artworkBytes!,
                          width: 300,
                          height: 300,
                          fit: BoxFit.cover,
                          gaplessPlayback:
                              true, // Giữ ảnh mượt khi Widget rebuild, ngăn chớp nháy
                        )
                      : const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Colors.tealAccent,
                        ),
                ),
              ),

              // ---------------------------
              const SizedBox(height: 20),
              TextScroll(
                currentSong?.title ?? "Đang phát",
                style: const TextStyle(color: Colors.tealAccent, fontSize: 24),
              ),
              const Spacer(),
              // thanh tiến trình theo thời gian thực
              Column(
                children: [
                  Slider(
                    activeColor: Colors.tealAccent,
                    // Đổi màu thanh trượt cho tone-sur-tone
                    inactiveColor: Colors.grey[800],
                    // Màu phần chưa chạy tới
                    value: _position.inSeconds.toDouble().clamp(
                      0.0,
                      _duration.inSeconds.toDouble(),
                    ),
                    max: _duration.inSeconds.toDouble(),
                    onChanged: (v) =>
                        widget.audioPlayer.seek(Duration(seconds: v.toInt())),
                  ),
                  // Hàng chứa 2 mốc thời gian
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ), // Căn lề cho khớp với thanh trượt
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
                      color: (Colors.tealAccent),
                    ),
                    onPressed: () => widget.audioPlayer.seekToPrevious(),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: (Colors.tealAccent),
                      size: 70,
                    ),
                    onPressed: () => isPlaying
                        ? widget.audioPlayer.pause()
                        : widget.audioPlayer.play(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      size: 50,
                      color: (Colors.tealAccent),
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

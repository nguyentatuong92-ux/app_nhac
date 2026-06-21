import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:volume_controller/volume_controller.dart';
import 'danh_sach_dang_phat.dart';
import 'music_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicController _musicController = MusicController();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  bool _showVolumeSlider = false;
  double _currentVolume = 0.5;
  Uint8List? _artworkBytes;
  String? _currentArtworkId;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    _initVolume();
    _musicController.currentItem.addListener(_onItemChanged);
    _onItemChanged(); // Initial fetch
  }

  @override
  void dispose() {
    _musicController.currentItem.removeListener(_onItemChanged);
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _initVolume() {
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then(
      (v) => setState(() => _currentVolume = v),
    );
    VolumeController.instance.addListener(
      (v) => setState(() => _currentVolume = v),
    );
  }

  void _onItemChanged() {
    final item = _musicController.currentItem.value;
    if (item != null && item.id != _currentArtworkId) {
      _currentArtworkId = item.id;
      if (item.extras?['is_online'] != true) {
        final id = int.tryParse(item.id);
        if (id != null) _fetchArtwork(id);
      } else {
        setState(() => _artworkBytes = null);
      }
    }
  }

  Future<void> _fetchArtwork(int id) async {
    try {
      final bytes = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        size: 500,
      );
      if (mounted) setState(() => _artworkBytes = bytes);
    } catch (e) {
      debugPrint("Lỗi lấy ảnh bìa: $e");
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0
        ? "${d.inHours}:$minutes:$seconds"
        : "$minutes:$seconds";
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
              _buildArtworkSection(artworkSize),
              const SizedBox(height: 20),
              ValueListenableBuilder<MediaItem?>(
                valueListenable: _musicController.currentItem,
                builder: (context, item, _) => TextScroll(
                  item?.title ?? "Đang phát",
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 24,
                  ),
                ),
              ),
              const Spacer(),
              _buildControlsRow(),
              const SizedBox(height: 15),
              _buildProgressSlider(),
              _buildPlaybackButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkSection(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ValueListenableBuilder<MediaItem?>(
          valueListenable: _musicController.currentItem,
          builder: (context, item, _) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF4B5563),
                borderRadius: BorderRadius.circular(size / 2),
                border: Border.all(color: Colors.tealAccent, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: item?.extras?['is_online'] == true
                    ? Image.network(
                        item!.artUri.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Colors.tealAccent,
                        ),
                      )
                    : (_artworkBytes != null
                          ? Image.memory(
                              _artworkBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          : const Icon(
                              Icons.music_note,
                              size: 100,
                              color: Colors.tealAccent,
                            )),
              ),
            );
          },
        ),
        StreamBuilder<ProcessingState>(
          stream: _musicController.audioPlayer.processingStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == ProcessingState.loading ||
                state == ProcessingState.buffering) {
              return CircularProgressIndicator(color: Colors.tealAccent);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: const Icon(
            Icons.queue_music,
            color: Colors.tealAccent,
            size: 30,
          ),
          onPressed: () =>
              DanhSachDangPhat.show(context, _musicController.audioPlayer),
        ),
        StreamBuilder<LoopMode>(
          stream: _musicController.audioPlayer.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            return IconButton(
              icon: Icon(
                loopMode == LoopMode.off
                    ? Icons.repeat
                    : (loopMode == LoopMode.all
                          ? Icons.repeat
                          : Icons.repeat_one),
                color: loopMode == LoopMode.off
                    ? Colors.grey
                    : Colors.tealAccent,
                size: 30,
              ),
              onPressed: () {
                final nextMode = loopMode == LoopMode.off
                    ? LoopMode.all
                    : (loopMode == LoopMode.all ? LoopMode.one : LoopMode.off);
                _musicController.audioPlayer.setLoopMode(nextMode);

                // Thêm thông báo nhanh
                String message = "";
                IconData icon = Icons.repeat;
                switch (nextMode) {
                  case LoopMode.off:
                    message = "Tắt lặp lại";
                    icon = Icons.repeat;
                    break;
                  case LoopMode.all:
                    message = "Lặp lại tất cả";
                    icon = Icons.repeat;
                    break;
                  case LoopMode.one:
                    message = "Lặp lại 1 bài";
                    icon = Icons.repeat_one;
                    break;
                }

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF64B5F6),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    content: Row(
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressSlider() {
    return StreamBuilder<Duration>(
      stream: _musicController.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = _musicController.audioPlayer.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              activeColor: Colors.tealAccent,
              inactiveColor: Colors.grey[800],
              value: pos.inSeconds.toDouble().clamp(
                0,
                dur.inSeconds.toDouble(),
              ),
              max: dur.inSeconds.toDouble() > 0
                  ? dur.inSeconds.toDouble()
                  : 1.0,
              onChanged: (v) => _musicController.audioPlayer.seek(
                Duration(seconds: v.toInt()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(pos),
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaybackButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(
            Icons.skip_previous,
            size: 50,
            color: Colors.tealAccent,
          ),
          onPressed: () => _musicController.audioPlayer.seekToPrevious(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _musicController.isPlaying,
          builder: (context, playing, _) => IconButton(
            icon: Icon(
              playing ? Icons.pause_circle : Icons.play_circle,
              color: Colors.tealAccent,
              size: 70,
            ),
            onPressed: () => playing
                ? _musicController.audioPlayer.pause()
                : _musicController.audioPlayer.play(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 50, color: Colors.tealAccent),
          onPressed: () => _musicController.audioPlayer.seekToNext(),
        ),
      ],
    );
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF2A2A3A),
      context: context,
      isScrollControlled:
          true, // Cho phép bottom sheet co giãn khi hiện bàn phím
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(c).viewInsets.bottom +
              20, // Đẩy lên khi hiện bàn phím và tránh thanh tác vụ
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Hẹn giờ tắt nhạc",
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.tealAccent, height: 1),
              ...[15, 30, 50].map(
                (m) => ListTile(
                  title: Text(
                    "$m Phút",
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(c);
                    _setSleepTimer(m);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.tealAccent),
                title: const Text(
                  "Tùy chọn thời gian",
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(c);
                  _showCustomTimerDialog();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomTimerDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Nhập số phút",
          style: TextStyle(color: Colors.tealAccent),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.tealAccent),
          decoration: const InputDecoration(
            hintText: "Nhập thời gian (phút)",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.tealAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final int? m = int.tryParse(controller.text);
              if (m != null && m > 0) {
                Navigator.pop(context);
                _setSleepTimer(m);
              }
            },
            child: const Text(
              "Hẹn giờ",
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _musicController.audioPlayer.pause();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF64B5F6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15.0,
              ), // Điều chỉnh độ bo góc tại đây
            ),
            content: Text(
              "Đã tự động tắt nhạc theo hẹn giờ ($minutes phút)",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF64B5F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            15.0,
          ), // Điều chỉnh độ bo góc tại đây
        ),
        duration: const Duration(seconds: 2),
        content: Text(
          "Nhạc sẽ tắt sau $minutes phút",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

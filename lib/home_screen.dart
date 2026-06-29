import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;
  int _cacheClearDays = 7; // Mặc định 7 ngày

  @override
  void initState() {
    super.initState();
    _initVolume();
    _initConnectivity();
    _initCacheSettings();
    _musicController.currentItem.addListener(_onItemChanged);
    _onItemChanged(); // Initial fetch
  }

  Future<void> _initCacheSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cacheClearDays = prefs.getInt('cache_clear_days') ?? 7;
    });
    _checkAndClearCache();
  }

  Future<void> _checkAndClearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClear = prefs.getInt('last_cache_clear_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Kiểm tra nếu đã đến hạn xóa
    if (now - lastClear > _cacheClearDays * 24 * 60 * 60 * 1000) {
      await _clearAppCache();
      await prefs.setInt('last_cache_clear_timestamp', now);
    }
  }

  Future<void> _clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.listSync().forEach((entity) {
          try {
            if (entity is File) {
              entity.deleteSync();
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
            }
          } catch (e) {
            debugPrint("Không thể xóa file: $e");
          }
        });
        debugPrint("Đã xóa bộ nhớ đệm thành công.");
      }
    } catch (e) {
      debugPrint("Lỗi khi xóa bộ nhớ đệm: $e");
    }
  }

  Future<void> _updateCacheSettings(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cache_clear_days', days);
    setState(() {
      _cacheClearDays = days;
    });
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _isOffline = result.contains(ConnectivityResult.none);
    });

    if (_isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          content: const Text(
            "Bạn đang ngoại tuyến. Chỉ có thể nghe nhạc đã tải.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _musicController.currentItem.removeListener(_onItemChanged);
    _sleepTimer?.cancel();
    _connectivitySubscription?.cancel();
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

    final accentColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Text(
              'Tá Tưởng',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
            ),
            if (_isOffline)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.wifi_off, color: Colors.redAccent, size: 20),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_left_sharp, color: accentColor),
          iconSize: 50,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: accentColor, size: 32),
            onPressed: _showSettingsBottomSheet,
          ),
          IconButton(
            icon: Icon(Icons.timer_outlined, color: accentColor, size: 38),
            onPressed: _showSleepTimerBottomSheet,
          ),
          IconButton(
            icon: Icon(
              _showVolumeSlider ? Icons.volume_up : Icons.volume_down,
              color: accentColor,
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
                  activeColor: accentColor,
                  inactiveColor: Colors.grey[800],
                  value: _currentVolume,
                  onChanged: (v) {
                    setState(() => _currentVolume = v);
                    VolumeController.instance.setVolume(v);
                  },
                ),
              const Spacer(),
              _buildArtworkSection(artworkSize, accentColor),
              const SizedBox(height: 20),
              ValueListenableBuilder<MediaItem?>(
                valueListenable: _musicController.currentItem,
                builder: (context, item, _) => TextScroll(
                  item?.title ?? "Đang phát",
                  style: TextStyle(color: accentColor, fontSize: 24),
                ),
              ),
              const Spacer(),
              _buildControlsRow(accentColor),
              const SizedBox(height: 15),
              _buildProgressSlider(accentColor),
              _buildPlaybackButtons(accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkSection(double size, Color accentColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ValueListenableBuilder<MediaItem?>(
          valueListenable: _musicController.currentItem,
          builder: (context, item, _) {
            return Hero(
              tag: 'music_artwork',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFF4B5563),
                  borderRadius: BorderRadius.circular(size / 2),
                  border: Border.all(color: accentColor, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size / 2),
                  child: item?.extras?['is_online'] == true
                      ? Image.network(
                          item!.artUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note,
                            size: 100,
                            color: accentColor,
                          ),
                        )
                      : (_artworkBytes != null
                            ? Image.memory(
                                _artworkBytes!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Icon(
                                Icons.music_note,
                                size: 100,
                                color: accentColor,
                              )),
                ),
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
              return CircularProgressIndicator(color: accentColor);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildControlsRow(Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(Icons.queue_music, color: accentColor, size: 30),
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
                color: loopMode == LoopMode.off ? Colors.grey : accentColor,
                size: 30,
              ),
              onPressed: () {
                final nextMode = loopMode == LoopMode.off
                    ? LoopMode.all
                    : (loopMode == LoopMode.all ? LoopMode.one : LoopMode.off);
                _musicController.audioPlayer.setLoopMode(nextMode);

                // Thêm thông báo nhanh
                String message = "";
                //IconData icon = Icons.repeat;
                switch (nextMode) {
                  case LoopMode.off:
                    message = "❌ Tắt lặp lại";
                    //icon = Icons.repeat;
                    break;
                  case LoopMode.all:
                    message = "✅ Lặp lại tất cả";
                    // icon = Icons.repeat;
                    break;
                  case LoopMode.one:
                    message = "✅ Lặp lại 1 bài";
                    //icon = Icons.repeat_one;
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
                        // Icon(icon, color: Colors.white),
                        // const SizedBox(width: 10),
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

  Widget _buildProgressSlider(Color accentColor) {
    return StreamBuilder<Duration>(
      stream: _musicController.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = _musicController.audioPlayer.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              activeColor: accentColor,
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
                    style: TextStyle(color: accentColor, fontSize: 18),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: TextStyle(color: accentColor, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaybackButtons(Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous, size: 50, color: accentColor),
          onPressed: () => _musicController.audioPlayer.seekToPrevious(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _musicController.isPlaying,
          builder: (context, playing, _) => IconButton(
            icon: Icon(
              playing ? Icons.pause_circle : Icons.play_circle,
              color: accentColor,
              size: 70,
            ),
            onPressed: () => playing
                ? _musicController.audioPlayer.pause()
                : _musicController.audioPlayer.play(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next, size: 50, color: accentColor),
          onPressed: () => _musicController.audioPlayer.seekToNext(),
        ),
      ],
    );
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).cardColor,
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...[15, 30, 50].map(
                (m) => ListTile(
                  title: Text(
                    "$m Phút",
                    style: const TextStyle(
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
                leading: const Icon(Icons.edit),
                title: const Text(
                  "Tùy chọn thời gian",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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
    final accentColor = Theme.of(context).colorScheme.primary;
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Nhập số phút", style: TextStyle(color: accentColor)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: accentColor),
          decoration: InputDecoration(
            hintText: "Nhập thời gian (phút)",
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accentColor),
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
            child: Text("Hẹn giờ", style: TextStyle(color: accentColor)),
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

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).cardColor,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (c) => SafeArea(
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Cài đặt hệ thống",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return SwitchListTile(
                  title: const Text("Chế độ tối"),
                  secondary: const Icon(Icons.dark_mode),
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleTheme(),
                );
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Màu sắc chủ đạo",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children:
                        [
                          Colors.tealAccent,
                          themeProvider.isDarkMode
                              ? Colors.blueAccent
                              : Colors.brown,
                          //Colors.blueAccent,
                          Colors.lightBlue,
                          Colors.orangeAccent,
                          Colors.purpleAccent,
                          themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black,
                          themeProvider.isDarkMode
                              ? Colors.lightGreenAccent
                              : Colors.red,
                          //Colors.lightGreenAccent,
                        ].map((color) {
                          final isSelected =
                              themeProvider.accentColor.toARGB32() ==
                              color.toARGB32();
                          return GestureDetector(
                            onTap: () => themeProvider.setAccentColor(color),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        width: 3,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text("Tự động xóa bộ nhớ đệm"),
              subtitle: Text("Hiện tại: $_cacheClearDays ngày"),
              onTap: () {
                Navigator.pop(c);
                _showCacheDayPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text("Xóa bộ nhớ đệm ngay lập tức"),
              onTap: () async {
                Navigator.pop(c);
                await _clearAppCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      content: const Text("Đã xóa sạch bộ nhớ đệm!"),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showCacheDayPicker() {
    final accentColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          "Chọn thời gian tự động xóa",
          style: TextStyle(color: accentColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [3, 7, 15].map((days) {
            return RadioListTile<int>(
              title: Text(
                "$days ngày",
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              value: days,
              groupValue: _cacheClearDays,
              activeColor: accentColor,
              onChanged: (val) {
                if (val != null) {
                  _updateCacheSettings(val);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

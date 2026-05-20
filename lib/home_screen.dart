import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';

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

  @override
  void initState() {
    super.initState();
    currentSong =
        widget.audioPlayer.sequenceState?.currentSource?.tag as SongModel?;
    widget.audioPlayer.sequenceStateStream.listen((state) {
      if (state != null && mounted) {
        setState(() => currentSong = state.currentSource?.tag as SongModel?);
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
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tắt hẹn giờ!')));
      return;
    }
    _sleepTimer = Timer(
      Duration(minutes: minutes),
      () => widget.audioPlayer.pause(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nhạc sẽ tự tắt sau $minutes phút nữa')),
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
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              int? m = int.tryParse(controller.text);
              if (m != null && m > 0) {
                Navigator.pop(context);
                _setSleepTimer(m);
              }
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text("15 Phút"),
            onTap: () {
              Navigator.pop(c);
              _setSleepTimer(15);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text("30 Phút"),
            onTap: () {
              Navigator.pop(c);
              _setSleepTimer(30);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text("60 Phút"),
            onTap: () {
              Navigator.pop(c);
              _setSleepTimer(60);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Tùy chỉnh..."),
            onTap: () {
              Navigator.pop(c);
              _showCustomTimerDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined, color: Colors.red),
            title: const Text(
              "Tắt hẹn giờ",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(c);
              _setSleepTimer(0);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Nguyễn Tá Tưởng',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 25,
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_showVolumeSlider)
              StreamBuilder<double>(
                stream: widget.audioPlayer.volumeStream,
                builder: (context, snapshot) => Slider(
                  value: snapshot.data ?? 1.0,
                  onChanged: (v) => widget.audioPlayer.setVolume(v),
                ),
              ),
            const Spacer(),
            Container(
              width: 300,
              height: 300,
              child: const Icon(
                Icons.music_note,
                size: 100,
                color: Colors.tealAccent,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(color: Colors.tealAccent, width: 3),
              ),
            ),

            const SizedBox(height: 20),
            TextScroll(
              currentSong?.title ?? "Đang phát",
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const Spacer(),
            Slider(
              value: _position.inSeconds.toDouble().clamp(
                0.0,
                _duration.inSeconds.toDouble(),
              ),
              max: _duration.inSeconds.toDouble(),
              onChanged: (v) =>
                  widget.audioPlayer.seek(Duration(seconds: v.toInt())),
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
    );
  }
}

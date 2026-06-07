import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'home_screen.dart';
import 'chon_nhieu_bai_hat.dart'; // Đã chèn import màn hình chọn nhiều bài
import 'package:just_audio_background/just_audio_background.dart';

final Map<int, List<SongModel>> globalPlaylistCache = {};

class PlaylistDetailsScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final AudioPlayer audioPlayer;
  final OnAudioQuery audioQuery;
  final Function(SongModel) onPlaySong;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlist,
    required this.audioPlayer,
    required this.audioQuery,
    required this.onPlaySong,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  List<SongModel> _songs = [];
  bool _isLoading = true;
  SongModel? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadSongs();

    _currentlyPlaying =
        widget.audioPlayer.sequenceState?.currentSource?.tag as SongModel?;

    widget.audioPlayer.sequenceStateStream.listen((state) {
      if (state == null) return;
      final song = state.currentSource?.tag as SongModel?;
      if (mounted && song?.id != _currentlyPlaying?.id) {
        setState(() {
          _currentlyPlaying = song;
        });
      }
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    int pId = widget.playlist.id;

    if (globalPlaylistCache.containsKey(pId)) {
      if (mounted) {
        setState(() {
          _songs = List.from(globalPlaylistCache[pId]!);
          _isLoading = false;
        });
      }
      return;
    }

    List<SongModel> rawSongs = await widget.audioQuery.queryAudiosFrom(
      AudiosFromType.PLAYLIST,
      pId,
    );
    List<SongModel> uniqueSongs = [];
    Set<String> seenPaths = {};

    for (var song in rawSongs) {
      if (!seenPaths.contains(song.data)) {
        uniqueSongs.add(song);
        seenPaths.add(song.data);
      }
    }

    globalPlaylistCache[pId] = uniqueSongs;

    if (mounted) {
      setState(() {
        _songs = List.from(uniqueSongs);
        _isLoading = false;
      });
    }
  }

  // ĐÃ CẬP NHẬT: Hàm mở màn hình chọn nhiều bài hát
  Future<void> _openAddSongMenu() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChonNhieuBaiHatScreen(
          playlist: widget.playlist,
          audioQuery: widget.audioQuery,
        ),
      ),
    );

    if (result == true) {
      // THÊM DÒNG NÀY: Xóa bộ nhớ đệm (cache) cũ của danh sách phát này
      globalPlaylistCache.remove(widget.playlist.id);

      // Gọi lại hàm load danh sách để ép ứng dụng tải dữ liệu mới nhất
      await _loadSongs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã thêm các bài hát vào danh sách!',
              style: TextStyle(color: Colors.tealAccent, fontSize: 18),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.playlist.playlist,
          style: const TextStyle(color: Colors.tealAccent),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.tealAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.tealAccent, size: 28),
            onPressed: _openAddSongMenu, // Gọi hàm mở màn hình
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
          ? const Center(
              child: Text(
                'Chưa có bài hát nào trong danh sách này.',
                style: TextStyle(color: Colors.tealAccent),
              ),
            )
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                bool isPlayingThisSong = _currentlyPlaying?.id == song.id;

                return ListTile(
                  leading: Icon(
                    isPlayingThisSong
                        ? Icons.play_circle_outline_outlined
                        : Icons.music_note,
                    color: isPlayingThisSong
                        ? Colors.tealAccent
                        : Colors.tealAccent,
                  ),
                  title: TextScroll(
                    song.title,
                    mode: TextScrollMode.bouncing,
                    velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    style: TextStyle(
                      color: isPlayingThisSong
                          ? Colors.tealAccent
                          : Colors.tealAccent,
                      fontWeight: isPlayingThisSong
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    song.artist ?? "Không biết",
                    style: const TextStyle(color: Colors.tealAccent),
                    maxLines: 1,
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.lime,
                    ),
                    onPressed: () async {
                      await widget.audioQuery.removeFromPlaylist(
                        widget.playlist.id,
                        song.id,
                      );
                      setState(() => _songs.removeAt(index));
                      globalPlaylistCache[widget.playlist.id] = _songs;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã xóa khỏi danh sách',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () async {
                    try {
                      final playlistSource = ConcatenatingAudioSource(
                        children: _songs.map((s) {
                          String uri = s.data.isNotEmpty
                              ? s.data
                              : (s.uri ??
                                    'content://media/external/audio/media/${s.id}');

                          return AudioSource.uri(
                            Uri.parse(uri),
                            // ĐÃ SỬA: Chuyển đổi sang MediaItem để đồng bộ với toàn hệ thống
                            tag: MediaItem(
                              id: s.id.toString(),
                              title: s.title,
                              artist: s.artist ?? "Không biết",
                              // Cấp luôn đường dẫn ảnh để bảng thông báo lên màu đẹp
                              artUri: s.albumId != null
                                  ? Uri.parse(
                                      'content://media/external/audio/albumart/${s.albumId}',
                                    )
                                  : Uri.parse(
                                      'asset:///assets/icon/music-notes-bg.jpg',
                                    ),
                            ),
                          );
                        }).toList(),
                      );

                      await widget.audioPlayer.setAudioSource(
                        playlistSource,
                        initialIndex: index,
                      );
                      widget.audioPlayer.play();

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                HomeScreen(audioPlayer: widget.audioPlayer),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Lỗi phát nhạc: $e',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
    );
  }
}

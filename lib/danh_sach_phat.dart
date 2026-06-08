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

  // Hàm này giúp cập nhật bài hát đang phát một cách an toàn
  // bằng cách kiểm tra linh hoạt kiểu dữ liệu của biến tag
  void _updateCurrentlyPlaying(dynamic tag) {
    if (tag == null) return;

    // Trường hợp 1: Nếu tag trả về đúng là SongModel
    if (tag is SongModel) {
      if (mounted && _currentlyPlaying?.id != tag.id) {
        setState(() {
          _currentlyPlaying = tag;
        });
      }
    }
    // Trường hợp 2: Nếu tag bị chuyển thành kiểu khác (thường là MediaItem)
    else {
      // Vì MediaItem.id thường là dạng String, ta cần chuyển nó về int
      // để có thể so sánh với id của SongModel
      final songIdString = tag.id.toString();
      final songId = int.tryParse(songIdString);

      if (songId != null && mounted && _currentlyPlaying?.id != songId) {
        try {
          // Tìm bài hát trong danh sách _songs dựa vào ID
          final song = _songs.firstWhere((s) => s.id == songId);
          setState(() {
            _currentlyPlaying = song;
          });
        } catch (e) {
          // Bỏ qua nếu không tìm thấy bài hát trong danh sách này
          debugPrint("Không tìm thấy bài hát trong danh sách: $e");
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSongs();

    // 1. Cập nhật trạng thái bài hát đang phát ngay khi mở màn hình
    _updateCurrentlyPlaying(
      widget.audioPlayer.sequenceState?.currentSource?.tag,
    );

    // 2. Lắng nghe luồng dữ liệu liên tục để cập nhật UI khi bài hát chuyển sang bài mới
    widget.audioPlayer.sequenceStateStream.listen((state) {
      if (state == null) return;
      _updateCurrentlyPlaying(state.currentSource?.tag);
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
            backgroundColor: Color(0xFF64B5F6),
            behavior: SnackBarBehavior.floating,
            // Giúp SnackBar nổi lên khỏi viền dưới
            shape: RoundedRectangleBorder(
              // Đã sửa: Đưa về cùng một dòng và dùng cú pháp an toàn cho const
              borderRadius: BorderRadius.all(Radius.circular(15.0)),
            ),
            content: Text(
              'Đã thêm các bài hát vào danh sách!',
              style: TextStyle(color: Colors.black, fontSize: 18),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0x901E293B),
      appBar: AppBar(
        title: Text(
          widget.playlist.playlist,
          style: const TextStyle(color: Colors.tealAccent),
        ),
        backgroundColor: Color(0xFF1E293B),
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
          // BẮT ĐẦU PHẦN THAY THẾ
          : ReorderableListView.builder(
              itemCount: _songs.length,
              // Hàm xử lý kéo thả
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  // Logic điều chỉnh index của Flutter
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  // Cập nhật vị trí trong danh sách _songs
                  final song = _songs.removeAt(oldIndex);
                  _songs.insert(newIndex, song);

                  // Cập nhật bộ nhớ đệm để giữ thứ tự mới
                  globalPlaylistCache[widget.playlist.id] = _songs;
                });
              },
              itemBuilder: (context, index) {
                final song = _songs[index];
                bool isPlayingThisSong = _currentlyPlaying?.id == song.id;

                return ListTile(
                  // QUAN TRỌNG: Thêm key dựa trên ID bài hát để Flutter nhận diện khi kéo thả
                  key: ValueKey(song.id),

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
                            backgroundColor: Color(0xFF64B5F6),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(15.0),
                              ),
                            ),
                            content: Text(
                              'Đã xóa khỏi danh sách',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () async {
                    // PHẦN CODE BÊN TRONG NÀY GIỮ NGUYÊN HOÀN TOÀN NHƯ CŨ
                    try {
                      final playlistSource = ConcatenatingAudioSource(
                        children: _songs.map((s) {
                          String uri = s.data.isNotEmpty
                              ? s.data
                              : (s.uri ??
                                    'content://media/external/audio/media/${s.id}');

                          return AudioSource.uri(
                            Uri.parse(uri),
                            tag: MediaItem(
                              id: s.id.toString(),
                              title: s.title,
                              artist: s.artist ?? "Không biết",
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

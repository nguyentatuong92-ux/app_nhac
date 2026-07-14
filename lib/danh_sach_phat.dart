import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:text_scroll/text_scroll.dart';
import 'chon_nhieu_bai_hat.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'music_controller.dart';

final Map<int, List<SongModel>> globalPlaylistCache = {};

class PlaylistDetailsScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final OnAudioQuery audioQuery;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlist,
    required this.audioQuery,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  List<SongModel> _songs = [];
  bool _isLoading = true;
  final MusicController _musicController = MusicController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
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
      globalPlaylistCache.remove(widget.playlist.id);
      await _loadSongs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF64B5F6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
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

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return "00:00";
    final d = Duration(milliseconds: ms);
    return "${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.playlist.playlist,
          style: TextStyle(color: accentColor),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: accentColor),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: accentColor, size: 28),
            onPressed: _openAddSongMenu,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _songs.isEmpty
          ? Center(
              child: Text(
                'Chưa có bài hát nào trong danh sách này.',
                style: TextStyle(color: accentColor),
              ),
            )
          : ValueListenableBuilder<MediaItem?>(
              valueListenable: _musicController.currentItem,
              builder: (context, currentItem, _) {
                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _songs.length,
                  onReorder: (int oldIndex, int newIndex) async {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final song = _songs.removeAt(oldIndex);
                      _songs.insert(newIndex, song);
                      globalPlaylistCache[widget.playlist.id] = _songs;
                    });

                    // Đồng bộ với hàng đợi đang phát
                    final currentItem = _musicController.currentItem.value;
                    final sourceName = currentItem?.extras?['source'];

                    if (sourceName == widget.playlist.playlist) {
                      try {
                        await _musicController.audioPlayer.moveAudioSource(
                          oldIndex,
                          newIndex,
                        );
                      } catch (e) {
                        debugPrint("Lỗi đồng bộ di chuyển: $e");
                      }
                    }
                  },
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    bool isPlayingThisSong =
                        currentItem?.id == song.id.toString();

                    return ListTile(
                      key: ValueKey(song.id),
                      leading: Icon(
                        isPlayingThisSong
                            ? Icons.play_circle_outline_outlined
                            : Icons.music_note,
                        color: isPlayingThisSong ? accentColor : Colors.white,
                      ),
                      title: TextScroll(
                        song.title,
                        mode: TextScrollMode.bouncing,
                        velocity: const Velocity(
                          pixelsPerSecond: Offset(30, 0),
                        ),
                        delayBefore: const Duration(seconds: 2),
                        pauseBetween: const Duration(seconds: 2),
                        style: TextStyle(
                          color: isPlayingThisSong
                              ? accentColor
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: isPlayingThisSong
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.artist ?? "Không biết",
                              style: TextStyle(
                                color: isPlayingThisSong
                                    ? accentColor
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            " • ${_formatDuration(song.duration)}",
                            style: TextStyle(
                              color: isPlayingThisSong
                                  ? accentColor
                                  : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.blueAccent,
                        ),
                        onPressed: () async {
                          await widget.audioQuery.removeFromPlaylist(
                            widget.playlist.id,
                            song.id,
                          );

                          // Đồng bộ với hàng đợi đang phát
                          final currentItem =
                              _musicController.currentItem.value;
                          final sourceName = currentItem?.extras?['source'];

                          if (sourceName == widget.playlist.playlist) {
                            try {
                              if (_musicController.audioPlayer.sequence.length >
                                  index) {
                                await _musicController.audioPlayer
                                    .removeAudioSourceAt(index);
                              }
                            } catch (e) {
                              debugPrint("Lỗi đồng bộ xóa: $e");
                            }
                          }

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
                      onTap: () => _musicController.playOfflineList(
                        _songs,
                        index,
                        source: widget.playlist.playlist,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

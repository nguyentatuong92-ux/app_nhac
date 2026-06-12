import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'danh_sach_phat.dart'; // Import để dùng globalPlaylistCache

class TabBaiHat extends StatefulWidget {
  final List<SongModel> allSongs;
  final bool isLoadingSongs;
  final AudioPlayer audioPlayer;
  final OnAudioQuery audioQuery;
  final SongModel? currentlyPlaying;
  final Set<int> deletedSongIds;
  final Function(int) onSongDeleted;
  final Function(List<SongModel>) onPlaySongs;

  const TabBaiHat({
    super.key,
    required this.allSongs,
    required this.isLoadingSongs,
    required this.audioPlayer,
    required this.audioQuery,
    required this.currentlyPlaying,
    required this.deletedSongIds,
    required this.onSongDeleted,
    required this.onPlaySongs,
  });

  @override
  State<TabBaiHat> createState() => _TabBaiHatState();
}

class _TabBaiHatState extends State<TabBaiHat> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#".split('');
  String _currentLetter = "A";
  final double _itemHeight = 75.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_dongBoChuCaiKhiCuon);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _dongBoChuCaiKhiCuon() {
    if (!_scrollController.hasClients) return;

    List<SongModel> songs = widget.allSongs
        .where((s) => !widget.deletedSongIds.contains(s.id))
        .toList();
    if (songs.isEmpty) return;

    int currentIndex = (_scrollController.offset / _itemHeight).floor();
    if (currentIndex >= 0 && currentIndex < songs.length) {
      String title = songs[currentIndex].title.trim();
      if (title.isNotEmpty) {
        String firstLetter = title[0].toUpperCase();
        if (!_alphabet.contains(firstLetter)) firstLetter = "#";

        if (_currentLetter != firstLetter) {
          setState(() {
            _currentLetter = firstLetter;
          });
        }
      }
    }
  }

  void _cuonDenChuCai(String letter, List<SongModel> songs) {
    int targetIndex = songs.indexWhere((song) {
      String title = song.title.trim().toUpperCase();
      if (letter == "#") return RegExp(r'^[^A-Z]').hasMatch(title);
      return title.startsWith(letter);
    });

    if (targetIndex != -1) {
      setState(() {
        _currentLetter = letter;
      });
      _scrollController.animateTo(
        targetIndex * _itemHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showAddToPlaylistBottomSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<PlaylistModel>>(
          future: widget.audioQuery.queryPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                ),
              );
            }
            if (snapshot.data == null || snapshot.data!.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    "Chưa có danh sách phát nào.",
                    style: TextStyle(color: Colors.tealAccent),
                  ),
                ),
              );
            }

            List<PlaylistModel> playlists = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(
                    Icons.queue_music,
                    color: Colors.tealAccent,
                  ),
                  title: Text(
                    playlists[index].playlist,
                    style: const TextStyle(color: Colors.tealAccent),
                  ),
                  onTap: () async {
                    await widget.audioQuery.addToPlaylist(
                      playlists[index].id,
                      song.id,
                    );
                    globalPlaylistCache.remove(playlists[index].id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF64B5F6),
                          behavior: SnackBarBehavior.floating,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(15.0),
                            ),
                          ),
                          content: Text(
                            'Đã thêm vào ${playlists[index].playlist}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(SongModel song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3A),
          title: const Text(
            'Xác nhận xóa',
            style: TextStyle(color: Colors.tealAccent),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa bài hát "${song.title}" khỏi thiết bị không? Hành động này không thể hoàn tác.',
            style: const TextStyle(color: Colors.tealAccent),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.tealAccent, fontSize: 20),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  if (song.data.isNotEmpty) {
                    if (await Permission.manageExternalStorage
                        .request()
                        .isGranted) {
                      final file = File(song.data);
                      if (await file.exists()) {
                        await file.delete();

                        // Báo cho tệp list_view.dart cập nhật danh sách
                        widget.onSongDeleted(song.id);

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
                                'Đã xóa bài hát khỏi thiết bị !',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  }
                } catch (e) {
                  debugPrint("Đã xảy ra lỗi Exception khi xóa file: $e");
                }
              },
              child: const Text(
                'Xóa',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.sort, color: Colors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Tên Bài Hát",
                    style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.isLoadingSongs
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                )
              : Builder(
                  builder: (context) {
                    List<SongModel> songs = widget.allSongs
                        .where((s) => !widget.deletedSongIds.contains(s.id))
                        .toList();

                    if (songs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không có bài hát nào.',
                          style: TextStyle(color: Colors.tealAccent),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.only(bottom: 100),
                          key: const PageStorageKey<String>('danh_sach_chinh'),
                          controller: _scrollController,
                          itemCount: songs.length,
                          separatorBuilder: (context, index) => const Divider(
                            color: Colors.grey,
                            height: 0.5,
                            indent: 80,
                          ),
                          itemBuilder: (context, index) {
                            bool isPlayingThisSong =
                                widget.currentlyPlaying?.id == songs[index].id;

                            return ListTile(
                              leading: SizedBox(
                                width: 50,
                                height: 50,
                                child: Stack(
                                  children: [
                                    QueryArtworkWidget(
                                      id: songs[index].id,
                                      type: ArtworkType.AUDIO,
                                      artworkBorder: BorderRadius.circular(8),
                                      artworkFit: BoxFit.cover,
                                      nullArtworkWidget: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white54,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    if (isPlayingThisSong)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.tealAccent,
                                          size: 28,
                                          shadows: [
                                            Shadow(
                                              color: Colors.tealAccent
                                                  .withOpacity(0.8),
                                              blurRadius: 10.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              title: TextScroll(
                                songs[index].title,
                                mode: TextScrollMode.bouncing,
                                velocity: const Velocity(
                                  pixelsPerSecond: Offset(30, 0),
                                ),
                                delayBefore: const Duration(seconds: 2),
                                pauseBetween: const Duration(seconds: 2),
                                style: TextStyle(
                                  color: isPlayingThisSong
                                      ? Colors.tealAccent
                                      : Colors.white,
                                  fontWeight: isPlayingThisSong
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                songs[index].artist ?? "Không biết",
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<int>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.tealAccent,
                                ),
                                color: const Color(0xFF1E293B),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20.0),
                                  ),
                                ),
                                onSelected: (value) {
                                  if (value == 1) {
                                    _showAddToPlaylistBottomSheet(songs[index]);
                                  } else if (value == 2) {
                                    _showDeleteConfirmDialog(songs[index]);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 1,
                                    child: Text(
                                      'Thêm vào danh sách phát',
                                      style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 2,
                                    child: Text(
                                      'Xóa bài hát',
                                      style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                try {
                                  // Chuyển mảng bài hát về tệp list_view.dart
                                  widget.onPlaySongs(songs);

                                  final playlistSource = ConcatenatingAudioSource(
                                    children: songs.map((s) {
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
                                                  'asset:///assets/icon/music-notes-bg.png',
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
                                } catch (e) {
                                  debugPrint("Lỗi phát nhạc: $e");
                                }
                              },
                            );
                          },
                        ),
                        // BẮT ĐẦU PHẦN THAY THẾ: Tự động căn chỉnh bằng tỷ lệ phần trăm
                        Align(
                          alignment: Alignment.centerRight,
                          // Tự động ép sát lề phải và căn giữa theo chiều dọc
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            // Cách mép phải 8 pixel an toàn
                            child: FractionallySizedBox(
                              heightFactor: 0.86,
                              // Tự động chiếm đúng 85% chiều cao khả dụng của mọi màn hình
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return GestureDetector(
                                    onVerticalDragUpdate: (details) {
                                      double letterHeight =
                                          constraints.maxHeight /
                                          _alphabet.length;
                                      int index =
                                          (details.localPosition.dy /
                                                  letterHeight)
                                              .floor();
                                      if (index >= 0 &&
                                          index < _alphabet.length) {
                                        _cuonDenChuCai(_alphabet[index], songs);
                                      }
                                    },
                                    child: Container(
                                      width: 26,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2A2A3A,
                                        ).withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(
                                          20.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: _alphabet.map((letter) {
                                          bool isSelected =
                                              _currentLetter == letter;
                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _cuonDenChuCai(letter, songs),
                                              child: Center(
                                                child: Text(
                                                  letter,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.tealAccent
                                                              .withOpacity(0.5),
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    fontSize: isSelected
                                                        ? 10
                                                        : 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // KẾT THÚC PHẦN THAY THẾ
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

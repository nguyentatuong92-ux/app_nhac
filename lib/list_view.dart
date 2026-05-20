// File: lib/list_view.dart
import 'dart:io'; // Thư viện để thao tác xóa file vật lý
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:text_scroll/text_scroll.dart'; // Thư viện chạy chữ
import 'home_screen.dart';
import 'danh_sach_phat.dart';
import 'package:text_scroll/text_scroll.dart';

class ListViewScreen extends StatefulWidget {
  const ListViewScreen({super.key});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _hasPermission = false;
  SongModel? currentlyPlaying;

  // BỘ NHỚ ĐEN: Ghi nhớ các bài đã xóa để chặn hiển thị lại
  final Set<int> _deletedSongIds = {};

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();

    _audioPlayer.sequenceStateStream.listen((state) {
      if (state == null) return;
      final song = state.currentSource?.tag as SongModel?;
      if (mounted && song != currentlyPlaying) {
        setState(() {
          currentlyPlaying = song;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    PermissionStatus status = await Permission.audio.request();
    if (status.isDenied) {
      status = await Permission.storage.request();
      if (status.isDenied)
        status = await Permission.manageExternalStorage.request();
    }
    if (status.isGranted) {
      setState(() => _hasPermission = true);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ứng dụng cần quyền để đọc bài hát!')),
        );
    }
  }

  // Bảng hiển thị thêm vào danh sách phát
  void _showAddToPlaylistBottomSheet(SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<PlaylistModel>>(
          future: _audioQuery.queryPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            if (snapshot.data == null || snapshot.data!.isEmpty)
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    "Chưa có danh sách phát nào.",
                    style: TextStyle(color: Colors.tealAccent),
                  ),
                ),
              );

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
                    await _audioQuery.addToPlaylist(
                      playlists[index].id,
                      song.id,
                    );
                    globalPlaylistCache.remove(playlists[index].id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã thêm vào ${playlists[index].playlist}',
                          ),
                        ),
                      );
                      setState(() {});
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

  // Hộp thoại xác nhận xóa bài hát
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
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Đóng hộp thoại
                try {
                  // Xóa file âm thanh vật lý trong máy
                  if (song.data.isNotEmpty) {
                    final file = File(song.data);
                    if (await file.exists()) {
                      await file.delete();
                    }
                  }

                  // Đưa bài hát vào danh sách đen để chặn nó hiển thị lại
                  setState(() {
                    _deletedSongIds.add(song.id);
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa bài hát khỏi thiết bị!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Không thể xóa: $e')),
                    );
                }
              },
              child: const Text(
                'Xóa',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3A),
          title: const Text(
            'Tạo Danh Sách Mới',
            style: TextStyle(color: Colors.tealAccent),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.tealAccent),
            decoration: const InputDecoration(
              hintText: 'Nhập tên danh sách...',
              hintStyle: TextStyle(color: Colors.tealAccent),
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
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _audioQuery.createPlaylist(controller.text);
                  setState(() {});
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text(
                'Tạo',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: const Text(
            'MUSIC APP',
            style: TextStyle(
              color: Colors.tealAccent,
              letterSpacing: 3.0,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.tealAccent),
          actions: [],
          bottom: const TabBar(
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.tealAccent,
            indicatorColor: Colors.tealAccent,
            tabs: [
              Tab(text: 'Bài hát', icon: Icon(Icons.music_note)),
              Tab(text: 'Danh sách phát', icon: Icon(Icons.queue_music)),
            ],
          ),
        ),
        body: !_hasPermission
            ? const Center(
                child: Text(
                  'Đang chờ cấp quyền...',
                  style: TextStyle(color: Colors.tealAccent),
                ),
              )
            : TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.sort,
                                  color: Colors.tealAccent,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Tên Bài Hát",
                                  style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: FutureBuilder<List<SongModel>>(
                          future: _audioQuery.querySongs(
                            ignoreCase: true,
                            orderType: OrderType.ASC_OR_SMALLER,
                            uriType: UriType.EXTERNAL,
                          ),
                          builder: (context, item) {
                            if (item.connectionState == ConnectionState.waiting)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            if (item.data == null || item.data!.isEmpty)
                              return const Center(
                                child: Text(
                                  'Không tìm thấy bài hát.',
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              );

                            // Lọc các bài hát đã bị xóa để không hiển thị lại
                            List<SongModel> songs = item.data!
                                .where((s) => !_deletedSongIds.contains(s.id))
                                .toList();

                            if (songs.isEmpty)
                              return const Center(
                                child: Text(
                                  'Không có bài hát nào.',
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              );

                            return ListView.separated(
                              itemCount: songs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    color: Colors.grey,
                                    height: 0.5,
                                    indent: 80,
                                  ),
                              itemBuilder: (context, index) {
                                bool isPlayingThisSong =
                                    currentlyPlaying?.id == songs[index].id;

                                return ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isPlayingThisSong
                                          ? Icons.play_circle_outline
                                          : Icons.music_note,
                                      color: isPlayingThisSong
                                          ? Colors.tealAccent
                                          : Colors.white70,
                                      size: 28,
                                      shadows: [
                                        Shadow(
                                          color: isPlayingThisSong
                                              // Bóng màu xanh mờ khi đang phát
                                              ? Colors.tealAccent.withOpacity(
                                                  0.6,
                                                ) // Bóng màu trắng mờ khi dừng
                                              : Colors.white54,
                                          // Độ tỏa sáng (bạn có thể tăng giảm số này)
                                          blurRadius: 10.0,
                                          offset: const Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // HIỆU ỨNG CHỮ CHẠY ĐƯỢC ÁP DỤNG TẠI ĐÂY
                                  title: TextScroll(
                                    songs[index].title,
                                    mode: TextScrollMode
                                        .bouncing, // Trượt qua trượt lại
                                    velocity: const Velocity(
                                      pixelsPerSecond: Offset(30, 0),
                                    ), // Tốc độ trượt
                                    delayBefore: const Duration(
                                      seconds: 2,
                                    ), // Nghỉ 2s trước khi trượt
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

                                  // MENU 3 CHẤM CÓ TÍNH NĂNG XÓA
                                  trailing: PopupMenuButton<int>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.tealAccent,
                                    ),
                                    color: const Color(0xFF2A2A3A),
                                    onSelected: (value) {
                                      if (value == 1) {
                                        _showAddToPlaylistBottomSheet(
                                          songs[index],
                                        );
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
                                          ),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 2,
                                        child: Text(
                                          'Xóa bài hát',
                                          style: TextStyle(
                                            color: Colors.tealAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  onTap: () async {
                                    try {
                                      final playlistSource =
                                          ConcatenatingAudioSource(
                                            children: songs.map((s) {
                                              String uri = s.data.isNotEmpty
                                                  ? s.data
                                                  : (s.uri ??
                                                        'content://media/external/audio/media/${s.id}');
                                              return AudioSource.uri(
                                                Uri.parse(uri),
                                                tag: s,
                                              );
                                            }).toList(),
                                          );

                                      await _audioPlayer.setAudioSource(
                                        playlistSource,
                                        initialIndex: index,
                                      );
                                      _audioPlayer.play();
                                    } catch (e) {
                                      print("Lỗi: $e");
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.add_circle,
                          color: Colors.tealAccent,
                          size: 40,
                        ),
                        title: const Text(
                          'Tạo danh sách phát mới',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => _showCreatePlaylistDialog(),
                      ),
                      const Divider(color: Colors.tealAccent, height: 1),
                      Expanded(
                        child: FutureBuilder<List<PlaylistModel>>(
                          future: _audioQuery.queryPlaylists(),
                          builder: (context, item) {
                            if (item.connectionState == ConnectionState.waiting)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            if (item.data == null || item.data!.isEmpty)
                              return const Center(
                                child: Text(
                                  'Chưa có danh sách phát.',
                                  style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 22,
                                  ),
                                ),
                              );

                            List<PlaylistModel> playlists = item.data!;
                            return ListView.builder(
                              itemCount: playlists.length,
                              itemBuilder: (context, index) {
                                int songCount = playlists[index].numOfSongs;
                                if (globalPlaylistCache.containsKey(
                                  playlists[index].id,
                                )) {
                                  songCount =
                                      globalPlaylistCache[playlists[index].id]!
                                          .length;
                                }

                                return ListTile(
                                  leading: const Icon(
                                    Icons.queue_music,
                                    color: Colors.tealAccent,
                                    size: 40,
                                  ),
                                  title: Text(
                                    playlists[index].playlist,
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$songCount bài hát',
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.tealAccent,
                                      size: 30,
                                    ),
                                    onPressed: () async {
                                      await _audioQuery.removePlaylist(
                                        playlists[index].id,
                                      );
                                      globalPlaylistCache.remove(
                                        playlists[index].id,
                                      );
                                      setState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PlaylistDetailsScreen(
                                              playlist: playlists[index],
                                              audioPlayer: _audioPlayer,
                                              audioQuery: _audioQuery,
                                              onPlaySong: (song) {},
                                            ),
                                      ),
                                    ).then((value) => setState(() {}));
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

        bottomNavigationBar: currentlyPlaying != null
            ? GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(audioPlayer: _audioPlayer),
                  ),
                ).then((_) => setState(() {})),
                child: Container(
                  height: 70,
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white54,
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // CHỮ CHẠY CHO THANH MINI-PLAYER
                            TextScroll(
                              currentlyPlaying!.title,
                              mode: TextScrollMode.bouncing,
                              velocity: const Velocity(
                                pixelsPerSecond: Offset(30, 0),
                              ),
                              delayBefore: const Duration(seconds: 2),
                              pauseBetween: const Duration(seconds: 2),
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentlyPlaying!.artist ?? "Không biết",
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () {
                          if (_audioPlayer.hasPrevious)
                            _audioPlayer.seekToPrevious();
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.tealAccent,
                          size: 35,
                        ),
                        onPressed: () => setState(() {
                          _audioPlayer.playing
                              ? _audioPlayer.pause()
                              : _audioPlayer.play();
                        }),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () {
                          if (_audioPlayer.hasNext) _audioPlayer.seekToNext();
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

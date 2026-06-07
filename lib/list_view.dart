// List_view.dart  trang chính
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:text_scroll/text_scroll.dart';
import 'cap_nhat_service.dart';
import 'danh_sach_phat.dart';
import 'widgets/mini_player.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart';

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

  final Set<int> _deletedSongIds = {};
  bool _coBanCapNhatMoi = false;

  List<SongModel> _danhSachDangPhat = [];

  Future<void> _kiemTraBanCapNhatNgam() async {
    bool coCapNhat = await CapNhatService.kiemTraCoBanCapNhatNgam();
    if (coCapNhat && mounted) {
      setState(() {
        _coBanCapNhatMoi = true;
      });
    }
  }

  // HÀM MỚI: Tự động kiểm tra quyền khi mở app
  Future<void> _kiemTraQuyenDaCap() async {
    // Kiểm tra trạng thái quyền Audio (dành cho Android 13+)
    bool audioGranted = await Permission.audio.isGranted;
    // Kiểm tra trạng thái quyền Storage (dành cho Android 12 trở xuống)
    bool storageGranted = await Permission.storage.isGranted;

    // Nếu hệ thống xác nhận đã cấp quyền từ lần mở app trước
    if (audioGranted || storageGranted) {
      if (mounted) {
        setState(() {
          _hasPermission = true; // Bật cờ cho phép vào thẳng danh sách nhạc
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _kiemTraQuyenDaCap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kiemTraBanCapNhatNgam();
    });

    // ĐÃ SỬA: Xóa bỏ đoạn mã bị lặp lại, chỉ giữ lại 1 lần lắng nghe
    _audioPlayer.currentIndexStream.listen((index) {
      if (index == null || _danhSachDangPhat.isEmpty) return;
      if (mounted) {
        setState(() {
          currentlyPlaying = _danhSachDangPhat[index];
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
    try {
      await Permission.audio.request();
      debugPrint("Đã xử lý xong quyền Audio");
    } catch (e) {
      debugPrint("Lỗi khi xin quyền Audio: $e");
    }

    try {
      await Permission.storage.request();
      debugPrint("Đã xử lý xong quyền Storage");
    } catch (e) {
      debugPrint("Lỗi khi xin quyền Storage: $e");
    }

    try {
      await Permission.manageExternalStorage.request();
      debugPrint("Đã xử lý xong quyền Manage Storage");
    } catch (e) {
      debugPrint("Lỗi khi xin quyền Manage Storage: $e");
    }

    if (mounted) {
      setState(() {
        _hasPermission = true;
      });
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
          future: _audioQuery.queryPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
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
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 20,
                            ),
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
                        print("Đã xóa file vật lý thành công!");
                        setState(() {
                          _deletedSongIds.add(song.id);
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã xóa bài hát khỏi thiết bị !',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          );
                        }
                      } else {
                        print(
                          "Lỗi: Không tìm thấy file ở đường dẫn ${song.data}",
                        );
                      }
                    } else {
                      print("Lỗi: Người dùng từ chối cấp quyền quản lý tệp.");
                    }
                  }
                } catch (e) {
                  print("Đã xảy ra lỗi Exception khi xóa file: $e");
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
          content: SingleChildScrollView(
            child: TextField(
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
                if (controller.text.isNotEmpty) {
                  await _audioQuery.createPlaylist(controller.text);
                  setState(() {});
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text(
                'Tạo',
                style: TextStyle(color: Colors.tealAccent, fontSize: 20),
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
          leading: IconButton(
            icon: Badge(
              isLabelVisible: _coBanCapNhatMoi,
              backgroundColor: Colors.redAccent,
              smallSize: 12,
              child: const Icon(Icons.add_alert, color: Colors.tealAccent),
            ),
            iconSize: 30,
            onPressed: () {
              if (_coBanCapNhatMoi) {
                setState(() {
                  _coBanCapNhatMoi = false;
                });
              }
              CapNhatService.kiemTra(context, showMessage: true);
            },
          ),
          iconTheme: const IconThemeData(color: Colors.tealAccent),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.tealAccent),
              tooltip: 'Làm mới danh sách',
              onPressed: () {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đang làm mới danh sách...',
                      style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                    ),
                  ),
                );
              },
            ),
          ],
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
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.folder_special,
                      size: 80,
                      color: Colors.tealAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ứng dụng cần quyền đọc file\nđể tải danh sách bài hát.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.tealAccent, fontSize: 18),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _checkAndRequestPermissions();
                      },
                      child: const Text(
                        'BẤM VÀO ĐÂY ĐỂ CẤP QUYỀN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
                                    fontSize: 18,
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
                            sortType: SongSortType.TITLE,
                            ignoreCase: true,
                            orderType: OrderType.ASC_OR_SMALLER,
                            uriType: UriType.EXTERNAL,
                          ),
                          builder: (context, item) {
                            if (item.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (item.data == null || item.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Không tìm thấy bài hát.',
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              );
                            }

                            List<SongModel> songs = item.data!
                                .where((s) => !_deletedSongIds.contains(s.id))
                                .toList();

                            if (songs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Không có bài hát nào.',
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              );
                            }

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
                                  leading: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Stack(
                                      children: [
                                        QueryArtworkWidget(
                                          id: songs[index].id,
                                          type: ArtworkType.AUDIO,
                                          artworkBorder: BorderRadius.circular(
                                            8,
                                          ),
                                          artworkFit: BoxFit.cover,
                                          nullArtworkWidget: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2A2A2A),
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                      _danhSachDangPhat = songs;

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
                            if (item.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (item.data == null || item.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Chưa có danh sách phát.',
                                  style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 22,
                                  ),
                                ),
                              );
                            }

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
            ? SafeArea(
                child: MiniPlayer(
                  currentSong: currentlyPlaying!,
                  audioPlayer: _audioPlayer,
                  onRefresh: () => setState(() {}),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

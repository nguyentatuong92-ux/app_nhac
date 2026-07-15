import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'music_controller.dart';
import 'danh_sach_phat.dart';

class TabBaiHat extends StatefulWidget {
  final List<SongModel> allSongs;
  final bool isLoadingSongs;
  final OnAudioQuery audioQuery;
  final Set<int> deletedSongIds;
  final Function(int) onSongDeleted;
  final VoidCallback onSongRenamed;
  final Future<void> Function()? onRefresh;

  const TabBaiHat({
    super.key,
    required this.allSongs,
    required this.isLoadingSongs,
    required this.audioQuery,
    required this.deletedSongIds,
    required this.onSongDeleted,
    required this.onSongRenamed,
    this.onRefresh,
  });

  @override
  State<TabBaiHat> createState() => _TabBaiHatState();
}

class _TabBaiHatState extends State<TabBaiHat> {
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 75.0;
  final MusicController _musicController = MusicController();

  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return "00:00";
    final d = Duration(milliseconds: ms);
    return "${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  void _showAddToPlaylistBottomSheet(SongModel song) {
    final accentColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<PlaylistModel>>(
          future: widget.audioQuery.queryPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              );
            }
            if (snapshot.data == null || snapshot.data!.isEmpty) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    "Chưa có danh sách phát nào.",
                    style: TextStyle(color: accentColor),
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
                  leading: Icon(Icons.queue_music, color: accentColor),
                  title: Text(
                    playlists[index].playlist,
                    style: TextStyle(color: accentColor),
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
    final accentColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Xác nhận xóa', style: TextStyle(color: accentColor)),
          content: Text(
            'Bạn có chắc chắn muốn xóa bài hát "${song.displayNameWOExt}" khỏi thiết bị không? Hành động này không thể hoàn tác.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: accentColor, fontSize: 20),
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

  void _showRenameDialog(SongModel song) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final TextEditingController controller = TextEditingController(
      text: song.displayNameWOExt,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Đổi tên bài hát', style: TextStyle(color: accentColor)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              hintText: "Nhập tên mới...",
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: accentColor, fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () async {
                String newName = controller.text.trim();
                if (newName.isEmpty || newName == song.displayNameWOExt) {
                  Navigator.pop(context);
                  return;
                }

                Navigator.pop(context);

                try {
                  if (await Permission.manageExternalStorage
                      .request()
                      .isGranted) {
                    File oldFile = File(song.data);
                    if (await oldFile.exists()) {
                      String dir = oldFile.parent.path;
                      String extension = song.data.split('.').last;
                      String newPath = "$dir/$newName.$extension";

                      await oldFile.rename(newPath);

                      // Cập nhật lại Media Store
                      await widget.audioQuery.scanMedia(newPath);

                      // Đợi một chút để hệ thống cập nhật database
                      await Future.delayed(const Duration(milliseconds: 1500));

                      if (mounted) {
                        widget.onSongRenamed();
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
                              'Đã đổi tên bài hát thành công!',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Không có quyền truy cập bộ nhớ!"),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint("Lỗi đổi tên: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi khi đổi tên: $e")),
                    );
                  }
                }
              },
              child: Text(
                'Lưu',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).cardColor,
      highlightColor: Theme.of(context).dividerColor,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Container(
              height: 15,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                height: 10,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final themeProvider = Provider.of<ThemeProvider>(context);

    List<SongModel> songs = widget.allSongs.where((s) {
      final isDeleted = widget.deletedSongIds.contains(s.id);
      if (isDeleted) return false;

      if (_searchQuery.isEmpty) return true;

      final titleMatches = s.displayNameWOExt.toLowerCase().contains(
        _searchQuery,
      );
      final artistMatches = (s.artist ?? "").toLowerCase().contains(
        _searchQuery,
      );

      return titleMatches || artistMatches;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: accentColor, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: "Tìm kiếm bài hát ...",
                          hintStyle: TextStyle(
                            color: accentColor.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? const Color(0xFF2A2A3A)
                              : Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: accentColor,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: accentColor,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchQuery = "";
                                _searchController.clear();
                              });
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      )
                    : Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(Icons.sort, color: accentColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Tên Bài Hát",
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "(${songs.length} bài hát)",
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (!_isSearching)
                IconButton(
                  icon: Icon(Icons.search, color: accentColor, size: 24),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: widget.isLoadingSongs
              ? _buildSkeletonLoading()
              : Builder(
                  builder: (context) {
                    if (songs.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Không có bài hát nào.'
                              : 'Không tìm thấy kết quả nào.',
                          style: TextStyle(color: accentColor, fontSize: 18),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: widget.onRefresh ?? () async {},
                      color: accentColor,
                      child: RawScrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 6.0,
                        radius: const Radius.circular(10),
                        thumbColor: accentColor.withValues(alpha: 0.6),
                        child: ValueListenableBuilder(
                          valueListenable: _musicController.currentItem,
                          builder: (context, currentItem, _) {
                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100),
                              key: const PageStorageKey<String>(
                                'danh_sach_chinh',
                              ),
                              controller: _scrollController,
                              itemCount: songs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                    color: Colors.grey,
                                    height: 0.5,
                                    indent: 80,
                                  ),
                              itemBuilder: (context, index) {
                                bool isPlayingThisSong =
                                    currentItem?.id ==
                                    songs[index].id.toString();

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
                                              color: Colors.black.withAlpha(
                                                128,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.play_circle_outline,
                                              color: accentColor,
                                              size: 28,
                                              shadows: [
                                                Shadow(
                                                  color: accentColor.withValues(
                                                    alpha: 0.8,
                                                  ),
                                                  blurRadius: 10.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  title: TextScroll(
                                    songs[index].displayNameWOExt,
                                    mode: TextScrollMode.bouncing,
                                    velocity: const Velocity(
                                      pixelsPerSecond: Offset(30, 0),
                                    ),
                                    delayBefore: const Duration(seconds: 2),
                                    pauseBetween: const Duration(seconds: 2),
                                    style: TextStyle(
                                      color: isPlayingThisSong
                                          ? accentColor
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                      fontWeight: isPlayingThisSong
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          songs[index].artist ?? "Không biết",
                                          style: TextStyle(color: accentColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        " • ${_formatDuration(songs[index].duration)}",
                                        style: TextStyle(color: accentColor),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<int>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: accentColor,
                                    ),
                                    color: Theme.of(context).cardColor,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(20.0),
                                      ),
                                    ),
                                    onSelected: (value) {
                                      if (value == 1) {
                                        _showAddToPlaylistBottomSheet(
                                          songs[index],
                                        );
                                      } else if (value == 2) {
                                        _showDeleteConfirmDialog(songs[index]);
                                      } else if (value == 3) {
                                        _showRenameDialog(songs[index]);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Thêm vào danh sách phát',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 3,
                                        child: Text(
                                          'Đổi tên bài hát',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 2,
                                        child: Text(
                                          'Xóa bài hát',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _musicController.playOfflineList(
                                    songs,
                                    index,
                                    source: 'offline',
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

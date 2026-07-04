import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'cap_nhat_service.dart';
import 'mini_player.dart';
import 'music_controller.dart';
import 'tab_bai_hat.dart';
import 'tab_danh_sach_tai.dart';
import 'tab_danh_sach_phat.dart';
import 'tab_online.dart';
import 'font_setting_dialog.dart';
import 'danh_sach_phat.dart';

class ListViewScreen extends StatefulWidget {
  const ListViewScreen({super.key});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MusicController _musicController = MusicController();

  bool _hasPermission = false;
  bool _coBanCapNhatMoi = false;

  List<SongModel> _allSongs = [];
  bool _isLoadingSongs = true;
  final Set<int> _deletedSongIds = {};
  final GlobalKey<TabDanhSachPhatState> _playlistTabKey = GlobalKey();

  Future<void> _kiemTraBanCapNhatNgam() async {
    bool coCapNhat = await CapNhatService.kiemTraCoBanCapNhatNgam();
    if (coCapNhat && mounted) {
      setState(() {
        _coBanCapNhatMoi = true;
      });
    }
  }

  Future<void> _kiemTraQuyenDaCap() async {
    bool audioGranted = await Permission.audio.isGranted;
    bool storageGranted = await Permission.storage.isGranted;

    if (audioGranted || storageGranted) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
        });
        _loadSongs();
      }
    }
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DISPLAY_NAME,
        ignoreCase: true,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );
      if (mounted) {
        setState(() {
          _allSongs = songs;
          _isLoadingSongs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSongs = false;
        });
        debugPrint("Lỗi tải bài hát: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _kiemTraQuyenDaCap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kiemTraBanCapNhatNgam();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      await Permission.audio.request();
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    } catch (e) {
      debugPrint("Lỗi khi xin quyền: $e");
    }

    if (mounted) {
      setState(() {
        _hasPermission = true;
      });
      _loadSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    String appBarTitle = 'BÀI HÁT';
    if (_tabController.index == 1) {
      appBarTitle = 'ĐÃ TẢI';
    } else if (_tabController.index == 2) {
      appBarTitle = 'DANH SÁCH';
    } else if (_tabController.index == 3) {
      appBarTitle = 'NHẠC ONLINE';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        title: Text(
          appBarTitle,
          style: TextStyle(
            color: accentColor,
            letterSpacing: 3.0,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Badge(
            isLabelVisible: _coBanCapNhatMoi,
            backgroundColor: Colors.redAccent,
            smallSize: 12,
            child: Icon(Icons.add_alert, color: accentColor),
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
        iconTheme: IconThemeData(color: accentColor),
        actions: [
          IconButton(
            icon: Icon(Icons.font_download, color: accentColor),
            tooltip: 'Thay đổi kiểu chữ',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const FontSettingDialog(),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: accentColor),
            tooltip: 'Làm mới danh sách',
            onPressed: () {
              // 1. Xóa bộ nhớ đệm playlist
              globalPlaylistCache.clear();

              // 2. Tải lại danh sách bài hát
              _loadSongs();

              // 3. Thông báo cho Tab Playlist cập nhật lại UI
              _playlistTabKey.currentState?.refresh();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF64B5F6),
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15.0)),
                  ),
                  content: const Text(
                    'Đã làm mới toàn bộ danh sách!',
                    style: TextStyle(color: Colors.black, fontSize: 18),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: accentColor,
          indicatorColor: accentColor,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          tabs: const [
            Tab(
              icon: Icon(Icons.music_note),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text('Bài hát')),
            ),
            Tab(
              icon: Icon(Icons.download_for_offline),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text('Đã tải')),
            ),
            Tab(
              icon: Icon(Icons.queue_music),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text('Danh sách')),
            ),
            Tab(
              icon: Icon(Icons.language),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text('Online')),
            ),
          ],
        ),
      ),
      body: !_hasPermission
          ? _buildPermissionUI()
          : TabBarView(
              controller: _tabController,
              children: [
                TabBaiHat(
                  allSongs: _allSongs,
                  isLoadingSongs: _isLoadingSongs,
                  audioQuery: _audioQuery,
                  deletedSongIds: _deletedSongIds,
                  onSongDeleted: (songId) {
                    setState(() {
                      _deletedSongIds.add(songId);
                    });
                  },
                  onSongRenamed: _loadSongs,
                ),
                TabDanhSachTai(
                  allSongs: _allSongs,
                  isLoadingSongs: _isLoadingSongs,
                  audioQuery: _audioQuery,
                  deletedSongIds: _deletedSongIds,
                  onSongDeleted: (songId) {
                    setState(() {
                      _deletedSongIds.add(songId);
                    });
                  },
                  onSongRenamed: _loadSongs,
                ),
                TabDanhSachPhat(key: _playlistTabKey, audioQuery: _audioQuery),
                TabOnline(audioPlayer: _musicController.audioPlayer),
              ],
            ),
      bottomNavigationBar: ValueListenableBuilder<MediaItem?>(
        valueListenable: _musicController.currentItem,
        builder: (context, item, _) {
          if (item != null) {
            return const SafeArea(child: MiniPlayer());
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPermissionUI() {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_special, size: 80, color: accentColor),
          const SizedBox(height: 20),
          Text(
            'Ứng dụng cần quyền đọc file\nđể tải danh sách bài hát.',
            textAlign: TextAlign.center,
            style: TextStyle(color: accentColor, fontSize: 18),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _checkAndRequestPermissions,
            child: const Text(
              'BẤM VÀO ĐÂY ĐỂ CẤP QUYỀN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

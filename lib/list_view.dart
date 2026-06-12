import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'cap_nhat_service.dart';
import 'mini_player.dart';
import 'tab_bai_hat.dart';
import 'tab_danh_sach_phat.dart';
import 'tab_online.dart';

class ListViewScreen extends StatefulWidget {
  const ListViewScreen({super.key});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _hasPermission = false;

  // BIẾN CHO NHẠC OFFLINE
  SongModel? currentlyPlaying;

  // --- MỚI THÊM: BIẾN CHO NHẠC ONLINE ---
  bool _isOnlinePlaying = false;
  String? _onlineTitle;
  String? _onlineArtist;
  String? _onlineThumbUrl;
  // --------------------------------------

  final Set<int> _deletedSongIds = {};
  bool _coBanCapNhatMoi = false;

  List<SongModel> _danhSachDangPhat = [];
  List<SongModel> _allSongs = [];
  bool _isLoadingSongs = true;

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
        sortType: SongSortType.TITLE,
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

  // --- MỚI THÊM: HÀM NHẬN DỮ LIỆU TỪ TAB ONLINE ---
  void _handlePlayOnline(String title, String artist, String thumbUrl) {
    setState(() {
      _isOnlinePlaying = true;
      _onlineTitle = title;
      _onlineArtist = artist;
      _onlineThumbUrl = thumbUrl;
      currentlyPlaying = null; // Xóa trạng thái bài Offline
    });
  }
  // ------------------------------------------------

  @override
  void initState() {
    super.initState();
    _kiemTraQuyenDaCap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kiemTraBanCapNhatNgam();
    });

    _audioPlayer.currentIndexStream.listen((index) {
      // MỚI THÊM: Bỏ qua update index nếu đang phát Online
      if (_isOnlinePlaying) return;

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0x901E293B),
        // ... (Phần AppBar giữ nguyên không đổi) ...
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
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
                    backgroundColor: Color(0xFF64B5F6),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                    content: Text(
                      'Đang làm mới danh sách...',
                      style: TextStyle(color: Colors.black, fontSize: 18),
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
              Tab(text: 'Danh sách', icon: Icon(Icons.queue_music)),
              Tab(text: 'Online', icon: Icon(Icons.language)),
            ],
          ),
        ),
        body: !_hasPermission
            ? Center(
                // ... (Phần hiển thị xin quyền giữ nguyên) ...
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
                      onPressed: () => _checkAndRequestPermissions(),
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
                  TabBaiHat(
                    allSongs: _allSongs,
                    isLoadingSongs: _isLoadingSongs,
                    audioPlayer: _audioPlayer,
                    audioQuery: _audioQuery,
                    currentlyPlaying: currentlyPlaying,
                    deletedSongIds: _deletedSongIds,
                    onSongDeleted: (songId) {
                      setState(() {
                        _deletedSongIds.add(songId);
                      });
                    },
                    onPlaySongs: (songs) {
                      setState(() {
                        _danhSachDangPhat = songs;
                        _isOnlinePlaying =
                            false; // MỚI THÊM: Hủy trạng thái Online khi chọn nhạc Offline
                      });
                    },
                  ),
                  TabDanhSachPhat(
                    audioQuery: _audioQuery,
                    audioPlayer: _audioPlayer,
                  ),

                  // MỚI THÊM: Truyền hàm callback vào TabOnline
                  TabOnline(
                    audioPlayer: _audioPlayer,
                    onPlay: _handlePlayOnline,
                  ),
                ],
              ),

        // --- MỚI THÊM: Điều kiện hiển thị MiniPlayer được nâng cấp ---
        bottomNavigationBar: (currentlyPlaying != null || _isOnlinePlaying)
            ? SafeArea(
                child: MiniPlayer(
                  // Dữ liệu cho MiniPlayer (dùng code MiniPlayer bản nâng cấp tôi đã gửi trước đó)
                  isOnline: _isOnlinePlaying,
                  currentSong: currentlyPlaying,
                  onlineTitle: _onlineTitle,
                  onlineArtist: _onlineArtist,
                  onlineThumbUrl: _onlineThumbUrl,
                  audioPlayer: _audioPlayer,
                  onRefresh: () => setState(() {}),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

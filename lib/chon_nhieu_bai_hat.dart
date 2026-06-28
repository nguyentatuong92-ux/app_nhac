import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class ChonNhieuBaiHatScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final OnAudioQuery audioQuery;

  const ChonNhieuBaiHatScreen({
    super.key,
    required this.playlist,
    required this.audioQuery,
  });

  @override
  State<ChonNhieuBaiHatScreen> createState() => _ChonNhieuBaiHatScreenState();
}

class _ChonNhieuBaiHatScreenState extends State<ChonNhieuBaiHatScreen> {
  // Biến Set để lưu trữ ID của các bài hát được tick chọn (không cho phép trùng lặp)
  final Set<int> _danhSachChon = {};
  bool _dangXuLy = false;

  // THÊM MỚI: Các biến để quản lý trạng thái tải và lưu trữ danh sách bài hát
  List<SongModel> _songs = [];
  bool _isLoading = true;

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return "00:00";
    final d = Duration(milliseconds: ms);
    return "${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    // THÊM MỚI: Chỉ gọi lấy dữ liệu 1 lần duy nhất khi mở màn hình
    _loadSongs();
  }

  // THÊM MỚI: Hàm xử lý tải bài hát
  Future<void> _loadSongs() async {
    try {
      final songs = await widget.audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        ignoreCase: true,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      // Kiểm tra mounted để đảm bảo màn hình chưa bị đóng trước khi cập nhật UI
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint("Lỗi tải bài hát: $e");
      }
    }
  }

  // Hàm xử lý khi người dùng nhấn nút Thêm
  Future<void> _themVaoDanhSachPhat() async {
    if (_danhSachChon.isEmpty) return;

    setState(() {
      _dangXuLy = true; // Hiện vòng xoay tải để người dùng biết đang xử lý
    });

    // Chạy vòng lặp: Thêm lần lượt từng bài hát đã chọn vào Playlist
    for (int songId in _danhSachChon) {
      await widget.audioQuery.addToPlaylist(widget.playlist.id, songId);
    }

    if (mounted) {
      // Trả về true để báo cho màn hình danh sách phát biết là đã thêm xong, cần làm mới UI
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: accentColor),
        // Hiển thị số lượng bài hát đang được chọn
        title: Text(
          'Đã chọn ${_danhSachChon.length} bài',
          style: TextStyle(color: accentColor),
        ),
        actions: [
          // Chỉ hiện nút Thêm khi có ít nhất 1 bài được chọn
          if (_danhSachChon.isNotEmpty)
            _dangXuLy
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: accentColor,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.check, size: 30, color: accentColor),
                    tooltip: 'Thêm vào danh sách',
                    onPressed: _themVaoDanhSachPhat,
                  ),
        ],
      ),
      // SỬA ĐỔI: Thay FutureBuilder bằng cách kiểm tra biến _isLoading
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _songs.isEmpty
          ? Center(
              child: Text(
                'Không có bài hát nào.',
                style: TextStyle(color: accentColor),
              ),
            )
          : ListView.builder(
              // THÊM MỚI: Khóa để giữ vị trí cuộn cho danh sách
              key: const PageStorageKey<String>('danh_sach_chon_bai_hat'),
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                // Kiểm tra xem bài hát này có đang nằm trong danh sách chọn không
                final isSelected = _danhSachChon.contains(song.id);

                return CheckboxListTile(
                  activeColor: accentColor,
                  // Màu khi được tick
                  checkColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  // Màu của dấu tick
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  // Màu viền ô vuông
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "${song.artist ?? "Không biết"} • ${_formatDuration(song.duration)}",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    nullArtworkWidget: Icon(
                      Icons.music_note,
                      color: accentColor,
                    ),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _danhSachChon.add(song.id); // Thêm vào danh sách
                      } else {
                        _danhSachChon.remove(song.id); // Bỏ khỏi danh sách
                      }
                    });
                  },
                );
              },
            ),
    );
  }
}

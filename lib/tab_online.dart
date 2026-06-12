import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'online_music_controller.dart'; // Nhúng Controller vào

class TabOnline extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Function(String title, String artist, String thumbUrl)? onPlay;

  const TabOnline({super.key, required this.audioPlayer, this.onPlay});

  @override
  State<TabOnline> createState() => _TabOnlineState();
}

class _TabOnlineState extends State<TabOnline>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMusic(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final searchList = await OnlineMusicController.yt.search.search(query);
      if (mounted) {
        setState(() {
          // Lưu kết quả vào Controller thay vì biến cục bộ
          OnlineMusicController.searchResults = searchList.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            onSubmitted: _searchMusic,
            style: const TextStyle(color: Colors.tealAccent), // Màu chữ khi gõ
            decoration: InputDecoration(
              // 2. Dòng chữ ẩn
              hintText: "Vui lòng nhập bài hát...",
              hintStyle: const TextStyle(color: Colors.blueGrey),
              filled: true,
              fillColor: const Color(0xFF2A2A3A),

              // 2. Icon tìm kiếm (Đã được nâng cấp thành nút bấm)
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.tealAccent),
                onPressed: () {
                  // Lấy nội dung chữ người dùng vừa nhập
                  final query = _searchController.text;

                  // Tự động thu gọn bàn phím xuống
                  FocusScope.of(context).unfocus();

                  // Thực hiện tìm kiếm
                  _searchMusic(query);
                },
              ),

              // 3. Dấu X ở cuối để xóa nội dung
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.tealAccent),
                onPressed: () {
                  _searchController.clear(); // Lệnh xóa trắng ô nhập
                },
              ),

              // 1. Bo tròn 4 góc
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0), // Độ bo tròn
                borderSide: BorderSide.none, // Ẩn đường viền mặc định
              ),

              // Căn chỉnh lại khoảng cách chữ bên trong cho cân đối
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              // Dùng ValueListenableBuilder để danh sách tự cập nhật khi đổi bài
              : ValueListenableBuilder<int>(
                  valueListenable: OnlineMusicController.currentIndex,
                  builder: (context, value, child) {
                    return ListView.builder(
                      itemCount: OnlineMusicController.searchResults.length,
                      itemBuilder: (context, index) {
                        final video =
                            OnlineMusicController.searchResults[index];
                        final isSelected =
                            index ==
                            value; // So sánh với biến 'value' từ builder

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              video.thumbnails.mediumResUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.tealAccent
                                  : Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            video.author,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.tealAccent
                                  : Colors.grey,
                            ),
                          ),
                          // --- THÊM NÚT TẢI VỀ Ở ĐÂY ---
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Colors.tealAccent,
                            ),
                            tooltip: "Tải bài hát này",
                            onPressed: () {
                              // Gọi hàm tải nhạc mà chúng ta vừa viết
                              OnlineMusicController.downloadSong(
                                video,
                                context,
                              );
                            },
                          ),
                          onTap: () async {
                            // Gọi hàm phát nhạc từ Controller (Xoáy tròn sẽ tự hiện ra từ đây)
                            await OnlineMusicController.playSong(
                              index,
                              widget.audioPlayer,
                              context,
                            );

                            // Cập nhật thẻ MiniPlayer
                            if (widget.onPlay != null) {
                              widget.onPlay!(
                                video.title,
                                video.author,
                                video.thumbnails.highResUrl,
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

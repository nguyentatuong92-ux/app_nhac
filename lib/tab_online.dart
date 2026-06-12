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
            decoration: const InputDecoration(
              hintText: "Tìm kiếm...",
              filled: true,
              fillColor: Color(0xFF2A2A3A),
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
                          onTap: () async {
                            await OnlineMusicController.playSong(
                              index,
                              widget.audioPlayer,
                              context,
                            );
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

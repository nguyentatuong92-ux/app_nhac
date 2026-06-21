import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'music_controller.dart';
import 'online_music_controller.dart';
import 'home_screen.dart';

class TabOnline extends StatefulWidget {
  final AudioPlayer audioPlayer;

  const TabOnline({super.key, required this.audioPlayer});

  @override
  State<TabOnline> createState() => _TabOnlineState();
}

class _TabOnlineState extends State<TabOnline>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final MusicController _musicController = MusicController();
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
          OnlineMusicController.searchResults = searchList.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${duration.inHours}:$minutes:$seconds"
        : "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                )
              : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        onSubmitted: _searchMusic,
        style: const TextStyle(color: Colors.tealAccent),
        decoration: InputDecoration(
          hintText: "Vui lòng nhập bài hát...",
          hintStyle: const TextStyle(color: Colors.blueGrey),
          filled: true,
          fillColor: const Color(0xFF2A2A3A),
          prefixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.tealAccent),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _searchMusic(_searchController.text);
            },
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.tealAccent),
            onPressed: () => _searchController.clear(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ValueListenableBuilder<int>(
      valueListenable: OnlineMusicController.currentIndex,
      builder: (context, currentIndexValue, _) {
        return ValueListenableBuilder<String>(
          valueListenable: OnlineMusicController.currentQueueType,
          builder: (context, queueType, _) {
            final results = OnlineMusicController.searchResults;
            return ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final video = results[index];
                final isPlaying =
                    index == currentIndexValue && queueType == "search";

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
                      color: isPlaying ? Colors.tealAccent : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    "${video.author} • ${_formatDuration(video.duration)}",
                    style: TextStyle(
                      color: isPlaying ? Colors.tealAccent : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () =>
                            OnlineMusicController.addToOnlinePlaylist(
                              video,
                              context,
                              widget.audioPlayer,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.download,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () =>
                            OnlineMusicController.downloadSong(video, context),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await _musicController.playOnlineSong(
                      index,
                      results,
                      "search",
                      context,
                    );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
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
}

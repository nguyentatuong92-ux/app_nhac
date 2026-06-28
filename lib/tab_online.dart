import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'dart:async';
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
  List<String> _searchHistory = [];
  bool _showHistory = false;
  final FocusNode _focusNode = FocusNode();
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _initConnectivity();
    _focusNode.addListener(() {
      setState(() {
        _showHistory = _focusNode.hasFocus && _searchHistory.isNotEmpty;
      });
    });
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    setState(() => _isOffline = result.contains(ConnectivityResult.none));
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      result,
    ) {
      setState(() => _isOffline = result.contains(ConnectivityResult.none));
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history = history.sublist(0, 10);
    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _deleteHistoryItem(String item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(item);
    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
      _showHistory = history.isNotEmpty && _focusNode.hasFocus;
    });
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
      _showHistory = false;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _searchMusic(String query) async {
    if (query.trim().isEmpty || _isOffline) return;
    _focusNode.unfocus();
    setState(() => _showHistory = false);
    _saveSearchQuery(query);
    setState(() => _isLoading = true);

    try {
      var searchList = await OnlineMusicController.yt.search.search(query);
      List<Video> allResults = searchList.toList();

      // Lấy thêm 2 trang kết quả nữa (tổng cộng khoảng 60 bài)
      for (int i = 0; i < 2; i++) {
        var nextPage = await searchList.nextPage();
        if (nextPage == null) break;
        searchList = nextPage;
        allResults.addAll(nextPage);
      }

      if (mounted) {
        setState(() {
          OnlineMusicController.searchResults = allResults;
          _isLoading = false;
        });

        if (allResults.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Không tìm thấy kết quả nào."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi tìm kiếm: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi tìm kiếm: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        if (_isOffline)
          Container(
            width: double.infinity,
            color: Colors.redAccent.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text(
              "Mất kết nối internet. Vui lòng kiểm tra lại mạng.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        _buildSearchField(),
        Expanded(
          child: _isOffline
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 60, color: Colors.blueGrey),
                      SizedBox(height: 10),
                      Text(
                        "Không có kết nối mạng",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 18),
                      ),
                    ],
                  ),
                )
              : _isLoading
              ? _buildSkeletonLoading()
              : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            enabled: !_isOffline,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => _searchMusic(value),
            style: TextStyle(color: themeProvider.accentColor),
            decoration: InputDecoration(
              hintText: _isOffline
                  ? "Bạn đang ngoại tuyến"
                  : "Vui lòng nhập bài hát...",
              hintStyle: const TextStyle(color: Colors.blueGrey),
              filled: true,
              fillColor: themeProvider.isDarkMode
                  ? const Color(0xFF2A2A3A)
                  : Colors.grey[200],
              prefixIcon: IconButton(
                icon: Icon(Icons.search, color: themeProvider.accentColor),
                onPressed: _isOffline
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        _searchMusic(_searchController.text);
                      },
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: themeProvider.accentColor),
                onPressed: () {
                  _searchController.clear();
                  if (!_isOffline) {
                    setState(() {
                      _showHistory = _searchHistory.isNotEmpty;
                    });
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
            ),
          ),
        ),
        if (_showHistory && !_isOffline)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF2A2A3A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Lịch sử tìm kiếm",
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearAllHistory,
                        child: const Text(
                          "Xóa hết",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchHistory.length,
                  itemBuilder: (context, index) {
                    final item = _searchHistory[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.history,
                        color: Colors.blueGrey,
                      ),
                      title: Text(
                        item,
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _deleteHistoryItem(item),
                      ),
                      onTap: () {
                        _searchController.text = item;
                        _searchMusic(item);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
      ],
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

  Widget _buildSearchResults() {
    final accentColor = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<int>(
      valueListenable: OnlineMusicController.currentIndex,
      builder: (context, currentIndexValue, _) {
        return ValueListenableBuilder<String>(
          valueListenable: OnlineMusicController.currentQueueType,
          builder: (context, queueType, _) {
            final results = OnlineMusicController.searchResults;

            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 80,
                      color: accentColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Nhập tên bài hát để tìm kiếm",
                      style: TextStyle(color: accentColor, fontSize: 18),
                    ),
                  ],
                ),
              );
            }

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
                  title: TextScroll(
                    video.title,
                    mode: TextScrollMode.bouncing,
                    velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
                    style: TextStyle(
                      color: isPlaying
                          ? accentColor
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isPlaying
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.author,
                          style: TextStyle(
                            color: isPlaying ? accentColor : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        " • ${_formatDuration(video.duration)}",
                        style: TextStyle(
                          color: isPlaying ? accentColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: accentColor,
                        ),
                        onPressed: () =>
                            OnlineMusicController.addToOnlinePlaylist(
                              video,
                              context,
                              widget.audioPlayer,
                            ),
                      ),
                      IconButton(
                        icon: Icon(Icons.download, color: accentColor),
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

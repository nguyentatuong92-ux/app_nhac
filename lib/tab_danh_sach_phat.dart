import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'danh_sach_phat.dart';
import 'danh_sach_online_view.dart';
import 'online_music_controller.dart';
import 'music_controller.dart';

class TabDanhSachPhat extends StatefulWidget {
  final OnAudioQuery audioQuery;

  const TabDanhSachPhat({super.key, required this.audioQuery});

  @override
  State<TabDanhSachPhat> createState() => _TabDanhSachPhatState();
}

class _TabDanhSachPhatState extends State<TabDanhSachPhat> {
  final MusicController _musicController = MusicController();

  void _showCreatePlaylistDialog() {
    final accentColor = Theme.of(context).colorScheme.primary;
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Tạo Danh Sách Mới',
            style: TextStyle(color: accentColor),
          ),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              style: TextStyle(color: accentColor),
              decoration: InputDecoration(
                hintText: 'Nhập tên danh sách...',
                hintStyle: TextStyle(color: accentColor),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accentColor),
                ),
              ),
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
                if (controller.text.isNotEmpty) {
                  await widget.audioQuery.createPlaylist(controller.text);
                  setState(() {});
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(
                'Tạo',
                style: TextStyle(color: accentColor, fontSize: 20),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getPlaylistTotalDuration(int playlistId) async {
    try {
      List<SongModel> songs = await widget.audioQuery.queryAudiosFrom(
        AudiosFromType.PLAYLIST,
        playlistId,
      );

      int totalMilliseconds = 0;
      for (var song in songs) {
        totalMilliseconds += (song.duration ?? 0);
      }

      if (totalMilliseconds == 0) return "";

      Duration duration = Duration(milliseconds: totalMilliseconds);
      int hours = duration.inHours;
      int minutes = duration.inMinutes % 60;
      int seconds = duration.inSeconds % 60;

      if (hours > 0) {
        return " • ${hours}g ${minutes}p";
      } else {
        return " • ${minutes}p ${seconds}s";
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        ValueListenableBuilder<List>(
          valueListenable: OnlineMusicController.onlinePlaylist,
          builder: (context, playlist, _) {
            return ListTile(
              leading: Icon(Icons.language, color: accentColor, size: 40),
              title: Text(
                'Danh sách nhạc Online',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${playlist.length} bài hát được thêm',
                style: TextStyle(color: accentColor),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnlinePlaylistDetailsScreen(
                      audioPlayer: _musicController.audioPlayer,
                    ),
                  ),
                );
              },
            );
          },
        ),
        Divider(color: accentColor, height: 1),
        ListTile(
          leading: Icon(Icons.add_circle, color: accentColor, size: 40),
          title: Text(
            'Tạo danh sách phát mới',
            style: TextStyle(
              color: accentColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: _showCreatePlaylistDialog,
        ),
        Divider(color: accentColor, height: 1),
        Expanded(
          child: FutureBuilder<List<PlaylistModel>>(
            future: widget.audioQuery.queryPlaylists(),
            builder: (context, item) {
              if (item.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: accentColor),
                );
              }
              if (item.data == null || item.data!.isEmpty) {
                return Center(
                  child: Text(
                    'Chưa có danh sách phát.',
                    style: TextStyle(color: accentColor, fontSize: 22),
                  ),
                );
              }

              List<PlaylistModel> playlists = item.data!;
              return ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  int songCount = playlists[index].numOfSongs;
                  if (globalPlaylistCache.containsKey(playlists[index].id)) {
                    songCount =
                        globalPlaylistCache[playlists[index].id]!.length;
                  }

                  return ListTile(
                    leading: Icon(
                      Icons.queue_music,
                      color: accentColor,
                      size: 40,
                    ),
                    title: Text(
                      playlists[index].playlist,
                      style: TextStyle(color: accentColor, fontSize: 18),
                    ),
                    subtitle: FutureBuilder<String>(
                      future: _getPlaylistTotalDuration(playlists[index].id),
                      builder: (context, snapshot) {
                        String timeString = snapshot.data ?? "";
                        return Text(
                          '$songCount bài hát$timeString',
                          style: TextStyle(color: accentColor),
                        );
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.indigoAccent,
                        size: 30,
                      ),
                      onPressed: () async {
                        await widget.audioQuery.removePlaylist(
                          playlists[index].id,
                        );
                        globalPlaylistCache.remove(playlists[index].id);
                        setState(() {});
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailsScreen(
                            playlist: playlists[index],
                            audioQuery: widget.audioQuery,
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
    );
  }
}

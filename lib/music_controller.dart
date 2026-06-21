import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'online_music_controller.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MusicController {
  static final MusicController _instance = MusicController._internal();
  factory MusicController() => _instance;
  MusicController._internal();

  final AudioPlayer audioPlayer = AudioPlayer();

  // State Notifiers
  final ValueNotifier<MediaItem?> currentItem = ValueNotifier<MediaItem?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(false);

  void init() {
    audioPlayer.sequenceStateStream.listen((state) {
      final item = state.currentSource?.tag as MediaItem?;
      currentItem.value = item;
      isOnline.value = item?.extras?['is_online'] == true;
    });

    audioPlayer.playerStateStream.listen((state) {
      isPlaying.value =
          state.playing && state.processingState != ProcessingState.completed;
    });
  }

  Future<void> playOfflineList(List<SongModel> songs, int initialIndex) async {
    final sources = <AudioSource>[];
    for (var s in songs) {
      String uri = s.data.isNotEmpty
          ? s.data
          : (s.uri ?? 'content://media/external/audio/media/${s.id}');
      sources.add(
        AudioSource.uri(
          Uri.parse(uri),
          tag: MediaItem(
            id: s.id.toString(),
            title: s.title,
            artist: s.artist ?? "Không biết",
            duration: s.duration != null
                ? Duration(milliseconds: s.duration!)
                : null,
            artUri: s.albumId != null
                ? Uri.parse(
                    'content://media/external/audio/albumart/${s.albumId}',
                  )
                : null,
            extras: {'is_online': false},
          ),
        ),
      );
    }

    await audioPlayer.setAudioSources(sources, initialIndex: initialIndex);
    audioPlayer.play();
  }

  Future<void> playOnlineSong(
    int index,
    List<Video> queue,
    String queueType,
    BuildContext context,
  ) async {
    await OnlineMusicController.playSong(
      index,
      audioPlayer,
      context,
      customQueue: queue,
      queueType: queueType,
    );
  }

  void dispose() {
    audioPlayer.dispose();
  }
}

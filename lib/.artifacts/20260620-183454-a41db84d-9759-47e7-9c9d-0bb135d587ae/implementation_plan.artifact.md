# Integrate Online Playlist into 'Danh sách' Tab

The goal is to show the "Online Playlist" (songs added via the '+' button in search results) within the 'Danh sách' tab, allowing users to view and play their curated online songs alongside local playlists.

## Proposed Changes

### [tab_danh_sach_phat.dart](file:///C:/LT_mobile/app_nhac/lib/tab_danh_sach_phat.dart)

- Add a special entry for "Danh sách nhạc Online" at the top of the list (below the "Create Playlist" button).
- This entry will show the count of songs currently in `OnlineMusicController.onlinePlaylist`.
- When tapped, it will navigate to a new screen `OnlinePlaylistDetailsScreen`.

### [NEW] [danh_sach_online_view.dart](file:///C:/LT_mobile/app_nhac/lib/danh_sach_online_view.dart)

- Create a new file to host `OnlinePlaylistDetailsScreen`.
- This screen will display the list of songs in `OnlineMusicController.onlinePlaylist`.
- Functionalities:
    - Tap to play a song (calls `OnlineMusicController.playSong` with `queueType: "playlist"`).
    - Remove a song from the playlist (calls a new method in `OnlineMusicController`).
    - Swipe to reorder songs in the playlist.

### [online_music_controller.dart](file:///C:/LT_mobile/app_nhac/lib/online_music_controller.dart)

- Add a method `removeFromOnlinePlaylist(int index)` to handle song removal.

## Verification Plan

### Manual Verification
- **Add to Online Playlist**:
    - Search for a song in the 'Online' tab.
    - Click the '+' button.
    - Verify a snackbar appears confirming the addition.
- **View in 'Danh sách' Tab**:
    - Switch to the 'Danh sách' tab.
    - Verify "Danh sách nhạc Online" is visible with the correct song count.
- **Play from Online Playlist**:
    - Click on "Danh sách nhạc Online".
    - Play a song.
    - Verify it plays correctly and the MiniPlayer updates.
- **Manage Online Playlist**:
    - Verify songs can be removed.
    - Verify song count updates in the 'Danh sách' tab.

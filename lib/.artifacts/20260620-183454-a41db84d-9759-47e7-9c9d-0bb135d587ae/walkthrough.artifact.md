# Walkthrough - Unified Now Playing List

I have successfully unified the "Now Playing List" (Offline) and "Online Queue" into a single, intelligent button.

## Changes Made

### 1. Unified Button in [HomeScreen](file:///C:/LT_mobile/app_nhac/lib/home_screen.dart)
- Removed the separate globe icon button for "Online Playlist".
- The remaining "Queue Music" icon button now serves as the single entry point for whatever is currently playing.

### 2. Universal [DanhSachDangPhat](file:///C:/LT_mobile/app_nhac/lib/danh_sach_dang_phat.dart)
- **Automatic Detection**: The bottom sheet now automatically detects if the user is listening to offline or online music and updates its title and behavior accordingly.
- **Unified List**: Both types of music are now rendered using a single `StreamBuilder` listening to `audioPlayer.sequenceStateStream`.
- **Rich UI**: Added artwork support for both:
    - **Offline**: Uses `QueryArtworkWidget` to show high-quality album art.
    - **Online**: Uses `Image.network` to show YouTube thumbnails.
- **Improved Functionality**:
    - **Removal**: Added a red "Remove" button to each item to easily kick songs out of the queue.
    - **Reordering**: Fixed reordering logic to stay in sync with `OnlineMusicController`, preventing the "wrong song title" issue on the MiniPlayer.
    - **Visual Feedback**: Added an `equalizer` icon to the currently playing song.

### 3. Cleanup
- Deleted the redundant [danh_sach_online.dart](file:///C:/LT_mobile/app_nhac/lib/danh_sach_online.dart) file.

## Verification Summary

### Manual Verification Results
- **Offline Path**: Verified that clicking the queue button while playing local songs shows the local playlist with artwork. Reordering works and updates the playback order.
- **Online Path**: Verified that playing from search or online playlist correctly populates the same queue view. Thumbnails are displayed correctly.
- **Sync**: Verified that moving or removing items in the list correctly updates the `OnlineMusicController`'s internal state, ensuring the MiniPlayer stays accurate.
- **UI**: The `HomeScreen` is now cleaner with one less redundant button.

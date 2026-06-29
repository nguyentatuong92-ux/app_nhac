# Walkthrough - Refactor Online Music List Item Actions

I have replaced the separate "Add to Playlist" and "Download" buttons with a single "more" (three-dot) button in the Online Music search results. This change saves significant screen space and provides a cleaner UI that is consistent with the local music tab.

## Changes

### Online Music Tab

#### [tab_online.dart](file:///C:/LT_mobile/app_nhac/lib/tab_online.dart)

1.  **Unified Actions**: Replaced the `Row` of `IconButton`s with a `PopupMenuButton` to save space.
2.  **Layout Smoothing**:
    -   Combined `author` and `duration` into a single `Text` widget in the `subtitle` (e.g., `Author • 05:00`). This prevents the duration from being pushed to the far right, creating a more unified content block.
    -   Added `contentPadding: const EdgeInsets.symmetric(horizontal: 16)` to the `ListTile` for consistent alignment.
    -   **Compact Menu Area**: Applied `padding: EdgeInsets.zero` and `BoxConstraints(minWidth: 32, maxWidth: 32)` to the `PopupMenuButton` to minimize the space it occupies on the right, allowing more room for song information.
    -   Added `themeProvider` to the `_buildSearchResults` method to handle theme-aware background colors for the popup menu.
    -   **Search Results Padding**: Added `padding: const EdgeInsets.only(bottom: 100)` to the search results list to ensure the last items are not covered by the mini-player at the bottom of the screen.

### Playback Queue (Bottom Sheet)

#### [danh_sach_dang_phat.dart](file:///C:/LT_mobile/app_nhac/lib/danh_sach_dang_phat.dart)

- **Bottom Overlap Fix**: Increased the bottom padding of the `ReorderableListView` from `20` to `80`. This ensures that the last song in the queue can be scrolled fully into view and is not covered by the system navigation bar (Home/Back buttons).

```dart
// Before (Subitle with Row)
subtitle: Row(
  children: [
    Expanded(child: Text(video.author, ...)),
    Text(" • ${_formatDuration(video.duration)}", ...),
  ],
),

// After (Unified Subtitle)
subtitle: Text(
  "${video.author} • ${_formatDuration(video.duration)}",
  style: ...,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

## Verification Summary

### Manual Verification
1. **Search UI**: Verified that search results now show a single `more_vert` icon on the right side of each list item.
2. **Action - Add to Playlist**: Clicked the menu and selected "Thêm vào danh sách". Confirmed the snackbar notification appeared.
3. **Action - Download**: Clicked the menu and selected "Tải xuống". Confirmed the download dialog appeared as expected.
4. **Theme Consistency**: Verified the menu background color adapts correctly to light and dark modes using `themeProvider`.

# Fix Bottom Overlap in Playback List

The bottom sheet showing the current playlist ("Danh sách đang phát") has its last items partially obscured by the system navigation bar or potential mini-player space (though in a bottom sheet, it's usually the system bar). Adding significant padding at the bottom of the list will allow the user to scroll the last item fully into view.

## Proposed Changes

### UI Components

#### [danh_sach_dang_phat.dart](file:///C:/LT_mobile/app_nhac/lib/danh_sach_dang_phat.dart)

- Increase the `bottom` padding in `ReorderableListView.builder` from `20` to `80`. This provides enough space so the last item is not covered by the system navigation buttons or the rounded corners of the device.

```diff
- padding: const EdgeInsets.only(bottom: 20),
+ padding: const EdgeInsets.only(bottom: 80),
```

---

## Verification Plan

### Manual Verification
1.  **Open Playback List**: While a song is playing (or in the queue), open the "Danh sách đang phát" bottom sheet (the queue icon).
2.  **Scroll to Bottom**: Scroll all the way to the end of the list.
3.  **Check Visibility**: Verify that the last item in the list is fully visible and not covered by the Android navigation bar (the three buttons at the bottom: Back, Home, Recents).

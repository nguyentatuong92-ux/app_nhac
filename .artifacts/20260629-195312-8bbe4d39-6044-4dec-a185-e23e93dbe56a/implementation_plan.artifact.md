# Move Search Close Button Inside the Rounded Bar

Improve the search bar layout by moving the 'X' (close/clear) button inside the rounded container, creating a more compact and integrated look.

## Proposed Changes

### UI Layout

#### [tab_bai_hat.dart](file:///C:/LT_mobile/app_nhac/lib/tab_bai_hat.dart)

- **Restructure Search Header**:
    - Remove the external `IconButton` that was used for closing the search.
    - Move the close logic into the `suffixIcon` property of the `TextField`'s `InputDecoration`.
    - Use an `IconButton` as the `suffixIcon` to ensure it is clickable and properly aligned within the rounded border.
    - Ensure the search bar takes up the full width available when active.

```dart
// New TextField structure
TextField(
  ...
  decoration: InputDecoration(
    ...
    suffixIcon: IconButton(
      icon: Icon(Icons.close, color: accentColor, size: 20),
      onPressed: () {
        setState(() {
          _isSearching = false;
          _searchQuery = "";
          _searchController.clear();
        });
      },
    ),
  ),
)
```

---

## Verification Plan

### Manual Verification
1. **Visual Check**: Activate search mode and verify the 'X' button is clearly inside the colored, rounded background.
2. **Functional Check**: Click the 'X' button inside the bar and verify it successfully exits search mode and clears the query.
3. **Alignment**: Ensure the 'X' button doesn't overlap the text or look unbalanced within the rounded shape.

# Kiểm tra tính năng tự động phát nhạc Online

Tính năng tự động phát nhạc (auto-play) khi chuyển bài trong danh sách Online được thực hiện thông qua cơ chế "placeholder" (vị trí chờ) và lắng nghe sự thay đổi chỉ mục (index) của trình phát.

## Phân tích hiện trạng

1.  **Cơ chế Placeholder**: Khi bắt đầu phát một danh sách Online (từ tìm kiếm hoặc playlist), `OnlineMusicController` nạp vào `AudioPlayer` một danh sách `ConcatenatingAudioSource`. Trong đó chỉ có bài hiện tại là có link thật, các bài còn lại là "placeholder" với URL giả định (`example.com/placeholder...`).
2.  **Tự động chuyển bài**:
    *   Khi một bài hát kết thúc, `just_audio` tự động chuyển sang index tiếp theo (là một placeholder).
    *   `OnlineMusicController` có một listener lắng nghe `currentIndexStream`.
    *   Khi thấy index thay đổi và trúng vào một placeholder, nó sẽ gọi `playSong` để lấy link stream thật từ YouTube và thay thế placeholder đó.
3.  **Chuyển bài thủ công**:
    *   Các nút Skip Next/Previous trong `HomeScreen` hoặc `MiniPlayer` cũng gọi `playSong` với index tương ứng.
    *   Khi click trực tiếp vào một bài trong danh sách `Danh sách Online`, `playSong` cũng được gọi để kích hoạt việc lấy link và phát.

## Các điểm cần kiểm tra và cải thiện

Mặc dù logic cơ bản đã ổn, có một số điểm có thể gây hiểu lầm hoặc lỗi nhẹ:

- **UX**: Khi bấm Next/Previous thủ công, `showLoading` được đặt là `false`, dẫn đến việc nếu mạng chậm, người dùng không thấy phản hồi gì trong vài giây cho đến khi nhạc bắt đầu.
- **Race Condition**: Biến `_isProcessing` ngăn chặn việc gọi `playSong` đồng thời. Nếu người dùng bấm Next quá nhanh, hoặc bấm Next ngay khi bài hát vừa tự động chuyển, yêu cầu sẽ bị bỏ qua.

## Proposed Changes

Tôi sẽ thực hiện một số kiểm tra và điều chỉnh nhỏ để đảm bảo tính năng hoạt động mượt mà hơn.

### Online Music Controller

#### [online_music_controller.dart](file:///C:/LT_mobile/app_nhac/lib/online_music_controller.dart)

- Thêm log debug để theo dõi quá trình tự động chuyển bài.
- Điều chỉnh logic `_isProcessing` để cho phép "ngắt" yêu cầu cũ nếu người dùng chọn một bài hát khác (tùy chọn, sẽ xem xét độ phức tạp).
- Đảm bảo `currentIndex.value` luôn được đồng bộ chính xác nhất.

### UI Improvements (Nếu cần)

#### [home_screen.dart](file:///C:/LT_mobile/app_nhac/lib/home_screen.dart)

- Cân nhắc hiển thị một chỉ báo loading nhẹ khi đang chuyển bài online mà không dùng dialog (để không chặn UI hoàn toàn).

## Verification Plan

### Automated Tests
- Do dự án Flutter hiện tại chưa có bộ test integration cho Audio, tôi sẽ thực hiện xác minh qua logcat.

### Manual Verification
1.  **Phát tự động**: Phát bài gần cuối danh sách Online, đợi bài hát kết thúc và kiểm tra xem bài tiếp theo có tự động nạp link và phát không.
2.  **Chuyển bài thủ công (Nút Next/Prev)**: Bấm liên tục và bấm chậm để kiểm tra độ phản hồi.
3.  **Chọn bài từ danh sách**: Mở "Danh sách Online" (bottom sheet), chọn các bài khác nhau và kiểm tra tính năng "auto-play on click".
4.  **Kiểm tra MiniPlayer**: Đảm bảo tên bài hát và ảnh bìa cập nhật đúng khi chuyển bài tự động.

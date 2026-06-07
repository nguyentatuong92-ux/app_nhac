//  file cap_nhap_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CapNhatService {
  // Đã sửa thành đường dẫn API chuẩn của GitHub để lấy bản Release mới nhất
  static const String _githubApiUrl =
      'https://api.github.com/repos/nguyentatuong92-ux/app_nhac/releases/latest';

  // --- HÀM MỚI: DÙNG ĐỂ KIỂM TRA NGẦM HIỂN THỊ CHẤM ĐỎ ---
  static Future<bool> kiemTraCoBanCapNhatNgam() async {
    try {
      // 1. Lấy phiên bản hiện tại của app
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Lấy thông tin bản phát hành mới nhất từ GitHub
      final response = await Dio().get(_githubApiUrl);

      if (response.statusCode == 200) {
        String latestVersion = response.data['tag_name'].toString().replaceAll(
          'v',
          '',
        );

        // 3. So sánh xem có bản mới không
        return _isNewVersionGreater(currentVersion, latestVersion);
      }
      return false;
    } catch (e) {
      debugPrint("Lỗi kiểm tra cập nhật ngầm: $e");
      return false; // Nếu lỗi mạng thì mặc định là không có
    }
  }

  static Future<void> kiemTra(
    BuildContext context, {
    bool showMessage = false,
  }) async {
    try {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color(0xFF64B5F6),
            behavior: SnackBarBehavior.floating,
            // Giúp SnackBar nổi lên khỏi viền dưới
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15.0,
              ), // Điều chỉnh độ bo góc tại đây
            ),
            content: const Text(
              "Đang kiểm tra cập nhật...",
              style: TextStyle(fontSize: 18),
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 1. Lấy phiên bản hiện tại của app (ví dụ: 1.0.0)
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Lấy thông tin bản phát hành mới nhất từ GitHub API
      final response = await Dio().get(_githubApiUrl);

      if (response.statusCode == 200) {
        // Tag trên github thường có chữ 'v' (vd: v1.0.2), ta cắt bỏ chữ 'v' để so sánh
        String latestVersion = response.data['tag_name'].toString().replaceAll(
          'v',
          '',
        );

        // Lấy link tải file APK đính kèm (ưu tiên file .apk đầu tiên tìm thấy)
        List assets = response.data['assets'];
        String? apkDownloadUrl;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url'];
            break;
          }
        }

        // 3. So sánh phiên bản chuyên sâu (Kiểm tra xem bản mới có thực sự LỚN HƠN bản hiện tại không)
        bool isUpdateAvailable = _isNewVersionGreater(
          currentVersion,
          latestVersion,
        );

        if (isUpdateAvailable && apkDownloadUrl != null) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, apkDownloadUrl);
          }
        } else if (showMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF64B5F6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  15.0,
                ), // Điều chỉnh độ bo góc tại đây
              ),
              content: const Text(
                "Bạn đang dùng phiên bản mới nhất!",
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra cập nhật: $e");
      if (showMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF64B5F6),
            content: const Text(
              "Không thể kiểm tra cập nhật lúc này.",
              style: TextStyle(fontSize: 18),
            ),
          ),
        );
      }
    }
  }

  // --- HÀM MỚI ĐƯỢC THÊM VÀO ĐỂ SO SÁNH PHIÊN BẢN ---
  static bool _isNewVersionGreater(String current, String latest) {
    // Tách chuỗi thành mảng các số nguyên (Ví dụ: "1.0.2" -> [1, 0, 2])
    List<int> currentParts = current
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    List<int> latestParts = latest
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    // Cân bằng độ dài của 2 mảng để tránh lỗi (đề phòng trường hợp so sánh "1.0" và "1.0.1")
    int maxLength = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;
    while (currentParts.length < maxLength) currentParts.add(0);
    while (latestParts.length < maxLength) latestParts.add(0);

    // So sánh từng cặp số từ trái sang phải
    for (int i = 0; i < maxLength; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true; // Nếu bản trên GitHub lớn hơn -> Có cập nhật
      }
      if (latestParts[i] < currentParts[i]) {
        return false; // Nếu bản trên GitHub nhỏ hơn -> Không cập nhật
      }
    }

    return false; // Nếu bằng nhau hoàn toàn ở mọi mặt -> Không cập nhật
  }

  // -------------------------------------------------

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc người dùng phải chọn
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Cập nhật mới!",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Đã có phiên bản $newVersion.\nBạn có muốn tải về và cài đặt ngay không?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Để sau", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
              ),
              onPressed: () {
                Navigator.pop(context); // Tắt bảng hỏi
                _downloadAndInstall(context, url); // Bắt đầu tải
              },
              child: const Text(
                "Cập nhật ngay",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String url,
  ) async {
    // Hiện bảng tiến trình tải
    ValueNotifier<double> progress = ValueNotifier(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Đang tải bản cập nhật...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: value,
                    color: const Color(0xFF38BDF8),
                    backgroundColor: Colors.white10,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${(value * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    try {
      // Tìm thư mục lưu tạm trên điện thoại
      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/update.apk";

      // Tải file
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progress.value = received / total;
          }
        },
      );

      // Tải xong, tắt bảng tiến trình
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Kích hoạt bộ cài đặt của Android
      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint("Lỗi tải file: $e");
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF64B5F6),
            behavior: SnackBarBehavior.floating,
            // Giúp SnackBar nổi lên khỏi viền dưới
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                15.0,
              ), // Điều chỉnh độ bo góc tại đây
            ),
            content: const Text("Lỗi tải xuống! Vui lòng kiểm tra lại mạng."),
          ),
        );
      }
    }
  }
}

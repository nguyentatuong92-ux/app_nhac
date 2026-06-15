// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart'; // 1. Import thư viện chạy ngầm
import 'list_view.dart';

// 2. Chuyển hàm main thành bất đồng bộ (async)
Future<void> main() async {
  // 3. Đảm bảo các widget của Flutter được khởi tạo trước khi gọi Native code
  WidgetsFlutterBinding.ensureInitialized();
  // Mở khóa đoạn code này và sửa lại dòng androidNotificationIcon
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.app_nhac.channel.audio',
    androidNotificationChannelName: 'Phát nhạc',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/launcher_icon',
    // THÊM DÒNG NÀY ĐỂ HIỆN NÚT TRÊN MÀN HÌNH KHÓA
    androidShowNotificationBadge: true,
    androidStopForegroundOnPause: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng Dụng Nhạc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
        canvasColor: const Color(0xFF1E293B),
        // KẾT THÚC PHẦN THÊM MỚI
      ),
      home: const ListViewScreen(), // Mở màn hình danh sách đầu tiên
    );
  }
}

// File: lib/main.dart
import 'package:flutter/material.dart';
import 'list_view.dart'; // Đổi thành gọi file list_view.dart

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ListViewScreen(), // Mở màn hình danh sách đầu tiên
    );
  }
}

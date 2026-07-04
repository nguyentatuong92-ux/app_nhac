import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _accentKey = 'accent_color';
  static const String _fontKey = 'font_family';

  bool _isDarkMode = true;
  Color _accentColor = Colors.tealAccent;
  String _fontFamily = 'Roboto';

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;
  String get fontFamily => _fontFamily;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    final colorValue = prefs.getInt(_accentKey) ?? Colors.tealAccent.toARGB32();
    _accentColor = Color(colorValue);
    _fontFamily = prefs.getString(_fontKey) ?? 'Roboto';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;

    // Tự động chuyển đổi giữa Trắng và Đen để đảm bảo độ tương phản
    if (!_isDarkMode && _accentColor.toARGB32() == Colors.white.toARGB32()) {
      _accentColor = Colors.black;
    } else if (_isDarkMode &&
        _accentColor.toARGB32() == Colors.black.toARGB32()) {
      _accentColor = Colors.white;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    await prefs.setInt(_accentKey, _accentColor.toARGB32());
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setFontFamily(String font) async {
    _fontFamily = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, font);
    notifyListeners();
  }

  ThemeData get themeData {
    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    final primaryColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final scaffoldBg = _isDarkMode
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme(_fontFamily, baseTheme.textTheme);
    } catch (e) {
      textTheme = baseTheme.textTheme;
    }

    return baseTheme.copyWith(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.white54,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primary: _accentColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: _accentColor,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: _accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _accentColor,
        unselectedLabelColor: _isDarkMode
            ? _accentColor.withValues(alpha: 0.6)
            : Colors.grey,
        indicatorColor: _accentColor,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
    );
  }
}

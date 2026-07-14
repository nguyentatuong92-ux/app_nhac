import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class FontSettingDialog extends StatelessWidget {
  const FontSettingDialog({super.key});

  static const List<String> fontOptions = [
    'Roboto',
    'Be Vietnam Pro',
    'Montserrat',
    'Lora',
    'Dancing Script',
    'Pacifico',
    'Playfair Display',
    'Kanit',
    'Lobster',
    'Quicksand',
    'Inconsolata',
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final accentColor = themeProvider.accentColor;

    return AlertDialog(
      backgroundColor: themeProvider.isDarkMode
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Chọn kiểu chữ',
        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: fontOptions.length,
          itemBuilder: (context, index) {
            final fontName = fontOptions[index];
            final isSelected = themeProvider.fontFamily == fontName;

            return ListTile(
              title: Text(
                fontName,
                style: GoogleFonts.getFont(fontName).copyWith(
                  color: isSelected
                      ? accentColor
                      : (themeProvider.isDarkMode
                            ? Colors.white70
                            : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: accentColor)
                  : null,
              onTap: () {
                themeProvider.setFontFamily(fontName);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Đóng',
            style: TextStyle(color: accentColor, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color appprimaryColor = Color(0xFF191B2A);
  static const Color appsecondaryColor = Color(0xFF21293C);
  // 1F2739
  static const Color textColorPrimary = Color(0xFF52958E);
  static const Color appprimaryBackgroundColor = Color(0xFFD9DFEB);

  static const Color limeGreen = Color(0xFF58D68D);
  static const Color sunsetOrange = Color(0xFFF39C12);
  static const Color glossyGrape = Color(0xFF9B59B6);

  static const Color secondryskyBlue = Color(0xFFCEE6F6);
  static const Color secondrylimeGreen = Color(0xFFD1F2EB);
  static const Color secondrysunsetOrange = Color(0xFFFDEBD0);
  static const Color secondryglossyGrape = Color(0xFFE8DAEF);

  static ValueNotifier<Color> secondaryColorNotifier =
      ValueNotifier<Color>(secondryskyBlue);

  // static final Map<Color, Color> secondaryColorMap = {
  //   skyBlue: secondryskyBlue,
  //   limeGreen: secondrylimeGreen,
  //   sunsetOrange: secondrysunsetOrange,
  //   glossyGrape: secondryglossyGrape,
  // };

  // static void updateColors(Color newPrimaryColor) {
  //   primaryColor = newPrimaryColor;
  //   // secondryColor = secondaryColorMap[newPrimaryColor] ?? secondryskyBlue;
  //   secondaryColorNotifier.value = secondryColor;
  // }

  static Future<void> loadPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColorValue = prefs.getInt('themeColor');
    if (savedColorValue != null) {
      final loadedPrimaryColor = Color(savedColorValue);
      // updateColors(
      //     loadedPrimaryColor); // Ensure both primary and secondary colors are updated
    }
  }

  static Future<void> savePrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    // updateColors(color); // Update both primary and secondary colors
  }

  static const Color midnightBlue = Color(0xFF2C3E50);
  static const Color ferrariRed = Color(0xFFFF2400);

  static const Color lightGray = Color(0xFFF4F6F7);
  static const Color steelGray = Color(0xFFD5D8DC);

  static const Color charcoal = Color(0xFF2C3E50);
  static const Color slateGray = Color(0xFF5D6D7E);
  static const Color mutedRed = Color(0xFFE74C3C);

  static const Color disabledGray = Color(0xFFBDC3C7);
}

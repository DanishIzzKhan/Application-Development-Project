import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ink = Color(0xFF1F1F1F);
  static const dark = Color(0xFF333333);
  static const text2 = Color(0xFF555555);
  static const hint = Color(0xFF6B6B6B);
  static const border = Color(0xFF8A8A8A);
  static const divider = Color(0xFFD4D4D4);
  static const surface = Color(0xFFF0F0F0);
}

TextStyle inter(double size,
        {FontWeight weight = FontWeight.w400, Color color = AppColors.ink}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dark,
      primary: AppColors.dark,
      surface: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}
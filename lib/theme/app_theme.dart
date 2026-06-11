import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color cream = Color(0xFFFFF8EC);
  static const Color darkInk = Color(0xFF1A1A2E);
  static const Color shadow = Color(0x55000000);

  static TextStyle baloo2(double size,
      {FontWeight weight = FontWeight.w700, Color color = darkInk}) {
    return GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);
  }

  static TextStyle fredoka(double size,
      {FontWeight weight = FontWeight.w400, Color color = darkInk}) {
    return GoogleFonts.fredoka(fontSize: size, fontWeight: weight, color: color);
  }

  static TextStyle mono(double size,
      {FontWeight weight = FontWeight.w400, Color color = darkInk}) {
    return GoogleFonts.jetBrainsMono(
        fontSize: size, fontWeight: weight, color: color);
  }

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF46C07A)),
      textTheme: GoogleFonts.fredokaTextTheme(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type system: Sora (display, used with restraint on headings & big
/// numbers) paired with Inter (body/UI text). Both are free, stable,
/// widely-supported Google Fonts that render consistently across
/// Android devices.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _sora(double size, FontWeight weight, {double? height, double? letterSpacing}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, height: height, letterSpacing: letterSpacing);

  static TextStyle _inter(double size, FontWeight weight, {double? height, double? letterSpacing}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, height: height, letterSpacing: letterSpacing);

  // Display / headings (Sora)
  static TextStyle displayLarge(Color color) =>
      _sora(34, FontWeight.w700, height: 1.15, letterSpacing: -0.5).copyWith(color: color);
  static TextStyle displayMedium(Color color) =>
      _sora(28, FontWeight.w700, height: 1.18, letterSpacing: -0.3).copyWith(color: color);
  static TextStyle headline(Color color) =>
      _sora(22, FontWeight.w700, height: 1.2).copyWith(color: color);
  static TextStyle title(Color color) =>
      _sora(18, FontWeight.w600, height: 1.25).copyWith(color: color);
  static TextStyle subtitle(Color color) =>
      _sora(15, FontWeight.w600, height: 1.3).copyWith(color: color);

  // Body / UI (Inter)
  static TextStyle bodyLarge(Color color) =>
      _inter(16, FontWeight.w400, height: 1.5).copyWith(color: color);
  static TextStyle bodyMedium(Color color) =>
      _inter(14, FontWeight.w400, height: 1.5).copyWith(color: color);
  static TextStyle bodySmall(Color color) =>
      _inter(12.5, FontWeight.w400, height: 1.45).copyWith(color: color);
  static TextStyle label(Color color) =>
      _inter(13, FontWeight.w600, height: 1.3, letterSpacing: 0.1).copyWith(color: color);
  static TextStyle caption(Color color) =>
      _inter(11.5, FontWeight.w500, height: 1.3, letterSpacing: 0.2).copyWith(color: color);
  static TextStyle button(Color color) =>
      _inter(15, FontWeight.w600, height: 1.2, letterSpacing: 0.1).copyWith(color: color);
  static TextStyle overline(Color color) =>
      _inter(11, FontWeight.w700, height: 1.2, letterSpacing: 1.2).copyWith(color: color);
}

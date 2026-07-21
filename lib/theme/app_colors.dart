import 'package:flutter/material.dart';

/// PDF Master Tools — design token palette.
///
/// Signature direction: "Signal Indigo" as the brand spine, with an
/// "Ember Coral" action accent, and four muted category families used
/// to color-code tool groups across the dashboard (PDF / Scan / QR /
/// Convert) so the grid reads at a glance instead of as a wall of
/// identical grey tiles.
class AppColors {
  AppColors._();

  // ---- Brand ----------------------------------------------------------
  static const Color brandIndigo = Color(0xFF4F46E5);
  static const Color brandIndigoDeep = Color(0xFF3730A3);
  static const Color brandIndigoSoft = Color(0xFFE8E6FD);
  static const Color accentCoral = Color(0xFFFF6B4A);
  static const Color accentCoralSoft = Color(0xFFFFE4DC);

  // ---- Category families (tool grid color coding) ---------------------
  static const Color pdfPrimary = Color(0xFF4F46E5); // indigo
  static const Color pdfSoft = Color(0xFFE8E6FD);

  static const Color scanPrimary = Color(0xFFFF6B4A); // coral
  static const Color scanSoft = Color(0xFFFFE4DC);

  static const Color qrPrimary = Color(0xFF0EA5A5); // teal
  static const Color qrSoft = Color(0xFFD9F5F2);

  static const Color convertPrimary = Color(0xFFF5A623); // amber
  static const Color convertSoft = Color(0xFFFFF1D6);

  // ---- Semantic ---------------------------------------------------------
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5A5);

  // ---- Light neutrals ----------------------------------------------------
  static const Color lightBg = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F0F7);
  static const Color lightBorder = Color(0xFFE5E4F0);
  static const Color lightTextPrimary = Color(0xFF15141F);
  static const Color lightTextSecondary = Color(0xFF6C6B7E);
  static const Color lightTextTertiary = Color(0xFFA4A3B5);

  // ---- Dark neutrals -------------------------------------------------
  static const Color darkBg = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF18181F);
  static const Color darkSurfaceAlt = Color(0xFF212129);
  static const Color darkBorder = Color(0xFF2B2B35);
  static const Color darkTextPrimary = Color(0xFFF4F4F8);
  static const Color darkTextSecondary = Color(0xFFA6A5B8);
  static const Color darkTextTertiary = Color(0xFF6E6D80);

  /// Soft colored shadow instead of flat grey — reads more premium.
  static List<BoxShadow> cardShadow(Brightness brightness, {Color? tint}) {
    final Color base = tint ?? brandIndigo;
    return [
      BoxShadow(
        color: base.withOpacity(brightness == Brightness.dark ? 0.20 : 0.10),
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -6,
      ),
    ];
  }
}

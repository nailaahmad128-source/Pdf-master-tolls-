import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.brandIndigo,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.brandIndigoDeep : AppColors.brandIndigoSoft,
      onPrimaryContainer: isDark ? Colors.white : AppColors.brandIndigoDeep,
      secondary: AppColors.accentCoral,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentCoralSoft,
      onSecondaryContainer: const Color(0xFF7A2E1B),
      tertiary: AppColors.qrPrimary,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      inverseSurface: isDark ? AppColors.lightSurface : AppColors.darkSurface,
      onInverseSurface: isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      inversePrimary: AppColors.brandIndigoSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: GoogleFonts.inter().fontFamily,

      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge(textPrimary),
        displayMedium: AppTextStyles.displayMedium(textPrimary),
        headlineMedium: AppTextStyles.headline(textPrimary),
        titleLarge: AppTextStyles.title(textPrimary),
        titleMedium: AppTextStyles.subtitle(textPrimary),
        bodyLarge: AppTextStyles.bodyLarge(textPrimary),
        bodyMedium: AppTextStyles.bodyMedium(textSecondary),
        bodySmall: AppTextStyles.bodySmall(textSecondary),
        labelLarge: AppTextStyles.button(textPrimary),
        labelSmall: AppTextStyles.caption(textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: AppTextStyles.headline(textPrimary),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: border, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandIndigo,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.button(Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border, width: 1.4),
          textStyle: AppTextStyles.button(textPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandIndigo,
          textStyle: AppTextStyles.button(AppColors.brandIndigo),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: AppTextStyles.bodyMedium(textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: AppColors.brandIndigo, width: 1.6),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: AppColors.brandIndigoSoft,
        labelStyle: AppTextStyles.label(textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        side: BorderSide.none,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: AppTextStyles.title(textPrimary),
        contentTextStyle: AppTextStyles.bodyMedium(textSecondary),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.brandIndigoSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption(selected ? AppColors.brandIndigo : textSecondary)
              .copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.brandIndigoDeep : textSecondary);
        }),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentCoral,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.brandIndigo : surfaceAlt,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/constants.dart';

class AppTheme {
  static ThemeData get dark  => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark  = brightness == Brightness.dark;
    final bg      = isDark ? CDark.bg       : CLight.bg;
    final surface = isDark ? CDark.surface  : CLight.surface;
    final border  = isDark ? CDark.border   : CLight.border;
    final ink     = isDark ? CDark.ink      : CLight.ink;
    final inkSoft = isDark ? CDark.inkSoft  : CLight.inkSoft;
    // In light: navy is primary; in dark: sky blue is primary
    final primary = isDark ? CDark.amber    : Brand.navy;
    final skyBlue = isDark ? CDark.accent   : Brand.sky;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness:  brightness,
        primary:     primary,
        secondary:   skyBlue,
        surface:     surface,
        error:       isDark ? CDark.red    : CLight.red,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   ink,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora', fontSize: 18,
          fontWeight: FontWeight.w700, color: ink,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.lg),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rd.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rd.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rd.md),
          borderSide: BorderSide(color: skyBlue, width: 1.5),
        ),
        labelStyle: TextStyle(color: inkSoft, fontFamily: 'Sora', fontSize: 12,
            fontWeight: FontWeight.w600, letterSpacing: 0.3),
        hintStyle: TextStyle(color: inkSoft, fontFamily: 'Sora', fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      dividerColor: border,
      fontFamily: 'Sora',
      textTheme: TextTheme(
        bodyLarge:   TextStyle(fontFamily: 'Sora', color: ink),
        bodyMedium:  TextStyle(fontFamily: 'Sora', color: ink),
        bodySmall:   TextStyle(fontFamily: 'Sora', color: inkSoft),
        titleLarge:  TextStyle(fontFamily: 'Sora', color: ink, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontFamily: 'Sora', color: ink, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(fontFamily: 'Sora', color: inkSoft),
        labelSmall:  TextStyle(fontFamily: 'Sora', color: inkSoft),
      ),
      iconTheme: IconThemeData(color: inkSoft, size: 20),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: inkSoft,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.xl),
          side: BorderSide(color: border),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.xxl)),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)),
      ),
    );
  }
}

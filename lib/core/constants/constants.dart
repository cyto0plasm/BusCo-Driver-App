// ─────────────────────────────────────────────────────────────
//  BUSCO DRIVER v7 — RIDEWAVE DESIGN TOKENS
//  Aesthetic: Cream · Sky Blue · Navy  (RideWave palette)
//  Supports light + dark mode via C.of(context)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

// ── STATIC BRAND COLORS (mode-independent) ───────────────────
class Brand {
  // RideWave core palette
  static const cream     = Color(0xFFF7F8F0); // main bg
  static const sky       = Color(0xFF7AAACE); // primary / interactive
  static const light     = Color(0xFF9CD5FF); // accent / highlights
  static const navy      = Color(0xFF355872); // text / headings / cards
  static const navyDark  = Color(0xFF1E3D52);
  // Semantic
  static const red       = Color(0xFFE05A5A);
  static const redLight  = Color(0xFFFF8080);
  static const green     = Color(0xFF4CAF50);
  static const teal      = Color(0xFF4CAF50);
  static const tealLight = Color(0xFF76C442);
  static const orange    = Color(0xFFD4853A);
  static const amber     = navy;  // alias — "primary action" colour
  static const gold      = sky;
  static const blue      = sky;
  static const blueLight = light;
  static const blueDim   = Color(0xFF2A5F8A);
}

// ── DARK PALETTE ─────────────────────────────────────────────
class CDark {
  static const bg         = Color(0xFF0D1117);  // HTML --bg
  static const bgAlt      = Color(0xFF0F1520);
  static const surface    = Color(0xFF161B22);  // HTML --surface
  static const surfaceLt  = Color(0xFF1C2430);
  static const surfaceHi  = Color(0xFF1E2A38);
  static const border     = Color(0xFF1E2D3D);  // ~rgba(255,255,255,0.07)
  static const borderHi   = Color(0xFF2A4060);
  static const ink        = Color(0xFFE8EDF2);  // HTML --text
  static const inkSoft    = Color(0xFF7A8694);  // HTML --muted
  static const inkHint    = Color(0xFF4A6070);
  static const amber      = Brand.sky;          // primary action = sky blue
  static const amberDim   = Color(0xFF0E1E2E);
  static const accent     = Brand.light;
  static const accentDim  = Color(0xFF0D1E30);
  static const navy       = Brand.navy;
  static const navyBt     = Color(0xFF3A6078);
  static const green      = Brand.green;
  static const greenBg    = Color(0xFF0D2010);
  static const red        = Brand.red;
  static const redBg      = Color(0xFF200C0C);
  static const orange     = Brand.orange;
  static const orangeBg   = Color(0xFF1E1008);
  static const blue       = Brand.light;
  static const blueBg     = Color(0xFF0D1E30);
  static const gold       = Brand.sky;
  static const goldBg     = Color(0xFF0E1E2E);
  static const onDark     = Color(0xFFE8EDF2);
  static const onAmber    = Color(0xFFFFFFFF);
}

// ── LIGHT PALETTE (RideWave cream-based) ──────────────────────
class CLight {
  static const bg         = Brand.cream;        // #F7F8F0
  static const bgAlt      = Color(0xFFEFF0E8);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceLt  = Color(0xFFF0F1E9);
  static const surfaceHi  = Color(0xFFFAFBF6);
  static const border     = Color(0xFFDDE0D4);
  static const borderHi   = Color(0xFFC8D4C0);
  static const ink        = Brand.navy;          // #355872
  static const inkSoft    = Color(0xFF5A7A90);
  static const inkHint    = Color(0xFF9AAAB8);
  static const amber      = Brand.navy;          // primary = navy
  static const amberDim   = Color(0xFFDCEBF5);
  static const accent     = Brand.sky;           // #7AAACE
  static const accentDim  = Color(0xFFD8ECF9);
  static const navy       = Brand.navy;
  static const navyBt     = Brand.navyDark;
  static const green      = Brand.green;
  static const greenBg    = Color(0xFFE8F5E9);
  static const red        = Brand.red;
  static const redBg      = Color(0xFFFBE9E9);
  static const orange     = Brand.orange;
  static const orangeBg   = Color(0xFFFBF0E3);
  static const blue       = Brand.sky;
  static const blueBg     = Color(0xFFD8ECF9);
  static const gold       = Brand.sky;
  static const goldBg     = Color(0xFFD8ECF9);
  static const onDark     = Color(0xFFFFFFFF);
  static const onAmber    = Color(0xFFFFFFFF);
}

// ── RUNTIME COLOR ACCESSOR ────────────────────────────────────
class C {
  final Color bg, bgAlt, surface, surfaceLt, surfaceHi, border, borderHi;
  final Color ink, inkSoft, inkHint;
  final Color amber, amberDim, accent, accentDim, navy, navyBt;
  final Color green, greenBg, red, redBg, orange, orangeBg;
  final Color blue, blueBg, gold, goldBg;
  final Color onDark, onAmber;

  const C._({
    required this.bg, required this.bgAlt,
    required this.surface, required this.surfaceLt, required this.surfaceHi,
    required this.border, required this.borderHi,
    required this.ink, required this.inkSoft, required this.inkHint,
    required this.amber, required this.amberDim,
    required this.accent, required this.accentDim,
    required this.navy, required this.navyBt,
    required this.green, required this.greenBg,
    required this.red, required this.redBg,
    required this.orange, required this.orangeBg,
    required this.blue, required this.blueBg,
    required this.gold, required this.goldBg,
    required this.onDark, required this.onAmber,
  });

  static const _dark = C._(
    bg: CDark.bg, bgAlt: CDark.bgAlt,
    surface: CDark.surface, surfaceLt: CDark.surfaceLt, surfaceHi: CDark.surfaceHi,
    border: CDark.border, borderHi: CDark.borderHi,
    ink: CDark.ink, inkSoft: CDark.inkSoft, inkHint: CDark.inkHint,
    amber: CDark.amber, amberDim: CDark.amberDim,
    accent: CDark.accent, accentDim: CDark.accentDim,
    navy: CDark.navy, navyBt: CDark.navyBt,
    green: CDark.green, greenBg: CDark.greenBg,
    red: CDark.red, redBg: CDark.redBg,
    orange: CDark.orange, orangeBg: CDark.orangeBg,
    blue: CDark.blue, blueBg: CDark.blueBg,
    gold: CDark.gold, goldBg: CDark.goldBg,
    onDark: CDark.onDark, onAmber: CDark.onAmber,
  );

  static const _light = C._(
    bg: CLight.bg, bgAlt: CLight.bgAlt,
    surface: CLight.surface, surfaceLt: CLight.surfaceLt, surfaceHi: CLight.surfaceHi,
    border: CLight.border, borderHi: CLight.borderHi,
    ink: CLight.ink, inkSoft: CLight.inkSoft, inkHint: CLight.inkHint,
    amber: CLight.amber, amberDim: CLight.amberDim,
    accent: CLight.accent, accentDim: CLight.accentDim,
    navy: CLight.navy, navyBt: CLight.navyBt,
    green: CLight.green, greenBg: CLight.greenBg,
    red: CLight.red, redBg: CLight.redBg,
    orange: CLight.orange, orangeBg: CLight.orangeBg,
    blue: CLight.blue, blueBg: CLight.blueBg,
    gold: CLight.gold, goldBg: CLight.goldBg,
    onDark: CLight.onDark, onAmber: CLight.onAmber,
  );

  static C of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

}

// ── SPACING ───────────────────────────────────────────────────
class Sp {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// ── RADIUS ────────────────────────────────────────────────────
class Rd {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 28;
  static const double full = 999;
}

// ── TYPOGRAPHY ────────────────────────────────────────────────
class T {
  static TextStyle h1({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 28, fontWeight: FontWeight.w700,
    color: c, letterSpacing: -0.8, height: 1.15);
  static TextStyle h2({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w700,
    color: c, letterSpacing: -0.4, height: 1.25);
  static TextStyle h3({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.w600,
    color: c, letterSpacing: -0.2);
  static TextStyle h4({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w600,
    color: c, letterSpacing: -0.1);
  static TextStyle body({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w400,
    color: c, height: 1.55);
  static TextStyle bodySm({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 12, fontWeight: FontWeight.w400,
    color: c, height: 1.4);
  static TextStyle label({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 10, fontWeight: FontWeight.w700,
    color: c, letterSpacing: 1.2);
  static TextStyle labelMd({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 11, fontWeight: FontWeight.w600,
    color: c, letterSpacing: 0.6);
  static TextStyle num({Color? c, double size = 24}) => TextStyle(
    fontFamily: 'IBMPlexMono', fontSize: size, fontWeight: FontWeight.w600,
    color: c, letterSpacing: -0.5);
  static TextStyle btn({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w700,
    color: c, letterSpacing: 0.3);
  static TextStyle mono({Color? c, double size = 13}) => TextStyle(
    fontFamily: 'IBMPlexMono', fontSize: size, fontWeight: FontWeight.w400,
    color: c, letterSpacing: 0.2);
  static TextStyle caption({Color? c}) => TextStyle(
    fontFamily: 'Sora', fontSize: 10, fontWeight: FontWeight.w500,
    color: c, letterSpacing: 0.5);
}

// ── APP CONFIG ────────────────────────────────────────────────
class Cfg {
  static const supabaseUrl  = 'https://kcdpfvatrwskpdghkxaz.supabase.co';
  static const supabaseKey  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtjZHBmdmF0cndza3BkZ2hreGF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4MDQwODUsImV4cCI6MjA4NzM4MDA4NX0.3c2vpocuM-yL-gyeI4MiijWcFXJ1nsDAnsczoCzpBCQ';
  static const restBase     = 'https://kcdpfvatrwskpdghkxaz.supabase.co/rest/v1/';
  static const cloudName    = 'dx6krxtgh';
  static const cloudUrl     = 'https://api.cloudinary.com/v1_1/dx6krxtgh/image/upload';
  static const uploadPreset = 'driver_profiles';
}

// ── STORAGE KEYS ─────────────────────────────────────────────
class SK {
  static const loggedIn   = 'logged_in';
  static const driverId   = 'driver_id';
  static const name       = 'name';
  static const email      = 'email';
  static const phone      = 'phone';
  static const licenseNo  = 'license_no';
  static const busId      = 'bus_id';
  static const busNumber  = 'bus_number';
  static const lineNumber = 'line_number';
  static const walletId   = 'wallet_id';
  static const balance    = 'balance';
  static const currency   = 'currency';
  static const avatarUrl  = 'avatar_url';
  static const tripId     = 'active_trip_id';
  static const themeMode  = 'theme_mode';
}

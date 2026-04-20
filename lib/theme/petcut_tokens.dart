import 'package:flutter/material.dart';

class PcColors {
  // Brand
  static const brand     = Color(0xFF1D9E75);
  static const brandTint = Color(0xFFE1F5EE);

  // Neutrals
  static const ink       = Color(0xFF1A1A1A);
  static const surface   = Color(0xFFFFFFFF);
  static const surface2  = Color(0xFFFAF8F3);
  static const border    = Color(0xFFEDE9DF);
  static const textSec   = Color(0xFF6B6B63);
  static const textTer   = Color(0xFF9A9A90);

  // Semantic — Perfect (green)
  static const okBg      = Color(0xFFEAF3DE);
  static const okAccent  = Color(0xFF639922);
  static const okText    = Color(0xFF173404);

  // Semantic — Caution (amber)
  static const warnBg     = Color(0xFFFAEEDA);
  static const warnAccent = Color(0xFFEF9F27);
  static const warnText   = Color(0xFF412402);

  // Semantic — Warning (red)
  static const dangerBg     = Color(0xFFFCEBEB);
  static const dangerAccent = Color(0xFFE24B4A);
  static const dangerText   = Color(0xFF501313);

  // Semantic — Suggestion (blue, actions only)
  static const infoBg     = Color(0xFFE6F1FB);
  static const infoAccent = Color(0xFF378ADD);
  static const infoText   = Color(0xFF042C53);
}

class PcText {
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w500, height: 1.15);
  static const h1      = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, height: 1.25);
  static const h2      = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);
  static const body    = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
  static const label   = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.88);
}

class PcRadius {
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 20.0;
  static const full = 999.0;
}

class PcSpace {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const xxl = 32.0;
}

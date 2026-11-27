import 'package:flutter/material.dart';

const Color vrPrimary = Color(0xFF2563EB);
const Color vrPrimaryLight = Color(0xFF3B82F6);
const Color vrBg = Color(0xFFF8FAFC);
const Color vrSurface = Color(0xFFFFFFFF);
const Color vrInk = Color(0xFF0F172A);
const Color vrMuted = Color(0xFF64748B);
const Color vrBorder = Color(0xFFE2E8F0);
const Color vrSuccess = Color(0xFF10B981);
const Color vrRecording = Color(0xFFF43F5E);
const Color vrWarning = Color(0xFFF59E0B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: vrPrimary,
    brightness: Brightness.light,
  ).copyWith(
    primary: vrPrimary,
    surface: vrSurface,
    onSurface: vrInk,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: vrBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: vrBg,
      foregroundColor: vrInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: vrInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: vrSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: vrBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: vrBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: vrPrimary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: vrPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: vrPrimary,
        minimumSize: const Size(48, 48),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: vrInk,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
    ),
  );
}

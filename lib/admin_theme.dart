import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AC {
  // Backgrounds
  static const bg       = Color(0xFF0B1120);
  static const surface  = Color(0xFF111827);
  static const card     = Color(0xFF1C2637);
  static const cardHover= Color(0xFF202F45);
  static const border   = Color(0xFF1F2F45);

  // Text
  static const text      = Color(0xFFF1F5F9);
  static const textSub   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF4B5563);

  // Accents
  static const indigo  = Color(0xFF818CF8);
  static const indigoDark = Color(0xFF6366F1);
  static const purple  = Color(0xFFA78BFA);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger  = Color(0xFFF87171);
  static const info    = Color(0xFF60A5FA);

  static ThemeData get theme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      cardColor: card,
      dividerColor: border,
      colorScheme: const ColorScheme.dark(
        primary: indigo,
        secondary: purple,
        surface: card,
        error: danger,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: indigo, width: 1.5)),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSub),
        prefixIconColor: textMuted,
      ),
    );
  }
}

// Shared widget helpers
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  const AdminCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? AC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.border),
      ),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

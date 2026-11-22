
import 'package:flutter/material.dart';
import 'database/distributed_db.dart';

/// একটা রঙের থিম (accent রং + background gradient)
class AppPalette {
  final String name;
  final Color primary;
  final Color secondary;
  final Color bg0;
  final Color bg1;
  final Color bg2;
  const AppPalette(
      this.name, this.primary, this.secondary, this.bg0, this.bg1, this.bg2);
}

class AppTheme {
  static const List<AppPalette> palettes = [
    AppPalette('Violet', Color(0xFF6C63FF), Color(0xFF8E7CFF),
        Color(0xFF1A2940), Color(0xFF16213E), Color(0xFF0D1B2A)),
    AppPalette('Ocean', Color(0xFF0EA5E9), Color(0xFF38BDF8),
        Color(0xFF0B2A45), Color(0xFF0A2038), Color(0xFF06141F)),
    AppPalette('Emerald', Color(0xFF10B981), Color(0xFF34D399),
        Color(0xFF0F2D2B), Color(0xFF0B2224), Color(0xFF06151A)),
    AppPalette('Sunset', Color(0xFFF97316), Color(0xFFFB923C),
        Color(0xFF2D1B1B), Color(0xFF221416), Color(0xFF150B0E)),
    AppPalette('Rose', Color(0xFFEC4899), Color(0xFFF472B6),
        Color(0xFF2E1A2E), Color(0xFF231425), Color(0xFF150C17)),
    AppPalette('Midnight', Color(0xFF7C83FF), Color(0xFFA5A9FF),
        Color(0xFF0A0A0F), Color(0xFF050508), Color(0xFF000000)),
  ];

  /// এখন কোন থিম চালু (palettes list-এর index)
  static final ValueNotifier<int> paletteNotifier = ValueNotifier<int>(0);

  static AppPalette get current {
    final i = paletteNotifier.value;
    return palettes[(i < 0 || i >= palettes.length) ? 0 : i];
  }

  static Color get primary => current.primary;
  static Color get secondary => current.secondary;
  static Color get bg0 => current.bg0;
  static Color get bg1 => current.bg1;
  static Color get bg2 => current.bg2;

  static LinearGradient get background => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg0, bg1, bg2],
  );

  /// প্রতিটা স্ক্রিনের build()-এর শুরুতে ডাকা হয়, যাতে থিম বদলালে স্ক্রিন নিজে নিজে আবার আঁকে
  static void watch(BuildContext context) {
    Theme.of(context);
  }

  /// অ্যাপ চালু হওয়ার সময় Node C থেকে সেভ করা থিম আনে
  static Future<void> loadSaved() async {
    final v = await DistributedDB.getSetting('palette', '0')
        .timeout(const Duration(seconds: 4), onTimeout: () => '0');
    final i = int.tryParse(v) ?? 0;
    paletteNotifier.value = (i < 0 || i >= palettes.length) ? 0 : i;
  }

  /// থিম বদলায় এবং Node C-র settings টেবিলে সেভ করে
  static Future<void> select(int index) async {
    paletteNotifier.value = index;
    await DistributedDB.setSetting('palette', '$index');
  }

  static ThemeData themeData() {
    final p = current;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.bg2,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: ColorScheme.dark(
        primary: p.primary,
        secondary: p.secondary,
        tertiary: const Color(0xFFFF6B9D),
        surface: p.bg1,
        onSurface: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: p.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

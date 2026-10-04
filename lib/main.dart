import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'database/database_helper.dart';

// Global notifier for theme change
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
// Global notifier for currency symbol change
ValueNotifier<String> currencyNotifier = ValueNotifier("৳");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper();

  // Load theme preference
  final themeStr = await db.getSetting('themeMode', 'dark');
  themeNotifier.value = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;

  // Load currency preference
  final currencyStr = await db.getSetting('currency', 'BDT (৳)');
  currencyNotifier.value = _getCurrencySymbol(currencyStr);

  runApp(const MyApp());
}

String _getCurrencySymbol(String currencyString) {
  if (currencyString.contains('৳')) return '৳';
  if (currencyString.contains('\$')) return '\$';
  if (currencyString.contains('€')) return '€';
  if (currencyString.contains('₹')) return '₹';
  return '৳';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Light Theme Configuration
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            primaryColor: const Color(0xFF6C63FF),
            scaffoldBackgroundColor: Colors.grey[50],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6C63FF),
              secondary: const Color(0xFF8E7CFF),
              tertiary: const Color(0xFFFF6B9D),
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Dark Theme Configuration
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            primaryColor: const Color(0xFF6C63FF),
            scaffoldBackgroundColor: const Color(0xFF0D1B2A),
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
              primary: const Color(0xFF6C63FF),
              secondary: const Color(0xFF8E7CFF),
              tertiary: const Color(0xFFFF6B9D),
              surface: const Color(0xFF16213E),
              onSurface: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

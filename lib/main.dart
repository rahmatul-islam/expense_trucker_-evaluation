
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'database/distributed_db.dart';
import 'app_theme.dart';

// (পুরনো কোডের সাথে মেলানোর জন্য রাখা হয়েছে; এখন অ্যাপ সবসময় dark)
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
// Global notifier for currency symbol change
ValueNotifier<String> currencyNotifier = ValueNotifier("৳");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Node C থেকে currency আর রঙের থিম একসাথে আনা হচ্ছে।
  // ৪ সেকেন্ডে না পেলে default নিয়ে অ্যাপ চালু হবে।
  final results = await Future.wait([
    DistributedDB.getSetting('currency', 'BDT (৳)')
        .timeout(const Duration(seconds: 4), onTimeout: () => 'BDT (৳)'),
    AppTheme.loadSaved(),
  ]);
  currencyNotifier.value = _getCurrencySymbol(results[0] as String);

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
    // থিম বদলালে পুরো MaterialApp নতুন রঙে আবার আঁকা হয়
    return ValueListenableBuilder<int>(
      valueListenable: AppTheme.paletteNotifier,
      builder: (context, _, __) {
        final theme = AppTheme.themeData();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: theme,
          darkTheme: theme,
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../database/distributed_db.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

/// লগইন স্ক্রিন - ইমেইল-পাসওয়ার্ড অথবা বায়োমেট্রিক (ফিঙ্গারপ্রিন্ট/ফেস) ব্যবহার করে সিস্টেমে প্রবেশ করার স্ক্রিন
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- স্টেট ভেরিয়েবলসমূহ ---
  final emailController = TextEditingController(); // ইমেইল ইনপুট কন্ট্রোলার
  final passController = TextEditingController();  // পাসওয়ার্ড ইনপুট কন্ট্রোলার
  final LocalAuthentication auth = LocalAuthentication(); // বায়োমেট্রিক অথেন্টিকেশন সার্ভিস instance
  bool _canCheckBiometrics = false; // বায়োমেট্রিক সাপোর্ট স্টেট

  @override
  void initState() {
    super.initState();
    _checkBiometrics(); // বায়োমেট্রিক সেটিংস পরীক্ষা
  }

  /// Node C-তে বায়োমেট্রিক সেভ করা সেটিংস সক্রিয় কিনা এবং ডিভাইসে বায়োমেট্রিক ফিচার সমর্থিত কিনা তা পরীক্ষা
  Future<void> _checkBiometrics() async {
    final enabledSetting = await DistributedDB.getSetting('biometrics_enabled', '0');
    if (enabledSetting == '1') {
      try {
        final canCheck = await auth.canCheckBiometrics;
        final isSupported = await auth.isDeviceSupported();
        if (mounted && canCheck && isSupported) {
          setState(() => _canCheckBiometrics = true);
          _authenticateWithBiometrics();
        }
      } catch (e) {
        debugPrint("Error checking biometrics: $e");
      }
    }
  }

  /// ফিঙ্গারপ্রিন্ট বা ফেস স্ক্যান করার সার্ভিস চালুকরণ এবং সেশন রিস্টোর করা
  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint/face to log in',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        // পূর্বে লগইন করা লাস্ট সেশনের ইমেইল রিস্টোর করে হোম স্ক্রিনে নেভিগেট করা
        if (DistributedDB.restoreLastSession()) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please log in with your email and password first"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Biometric auth error: $e");
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  /// লগইন স্ক্রিনের মূল UI বিল্ড মেথড
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/login.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: 80),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Log in to your account",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 50),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Email",
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                        Divider(color: Colors.white24),
                        TextField(
                          controller: passController,
                          obscureText: true,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                          ),
                          onPressed: () async {
                            // Node C তে ইউজার এবং পাসওয়ার্ড ভ্যালিডেশন
                            final ok = await DistributedDB.login(
                              emailController.text.trim(),
                              passController.text.trim(),
                            );
                            if (!context.mounted) return;
                            if (ok) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => HomeScreen()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Invalid email or password"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: Text(
                            "LOGIN",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (_canCheckBiometrics) ...[
                        SizedBox(width: 15),
                        GestureDetector(
                          onTap: _authenticateWithBiometrics,
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SignupScreen()),
                      );
                    },
                    child: Text(
                      "Don't have an account? Create one",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

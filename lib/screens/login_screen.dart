import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../database/distributed_db.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabledSetting = await DistributedDB.getSetting('biometrics_enabled', '0');
    if (enabledSetting == '1') {
      try {
        final canCheck = await auth.canCheckBiometrics;
        final isSupported = await auth.isDeviceSupported();
        if (canCheck && isSupported) {
          setState(() => _canCheckBiometrics = true);
          _authenticateWithBiometrics();
        }
      } catch (e) {
        debugPrint("Error checking biometrics: $e");
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint/face to log in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Log in to your account",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Email",
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        TextField(
                          controller: passController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
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
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                          ),
                          onPressed: () async {
                            // Node C তে login check
                            final ok = await DistributedDB.login(
                              emailController.text.trim(),
                              passController.text.trim(),
                            );
                            if (!context.mounted) return;
                            if (ok) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const HomeScreen()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Invalid email or password"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          child: const Text(
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
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: _authenticateWithBiometrics,
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
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
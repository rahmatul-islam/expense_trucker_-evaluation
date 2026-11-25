// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../database/distributed_db.dart';

/// সাইনআপ স্ক্রিন - নতুন ইউজার অ্যাকাউন্ট খোলা এবং পাসওয়ার্ড পাসওয়ার্ড-হ্যাশিং (SHA-256) এর মাধ্যমে Node C তে সেভ করা
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // --- ইনপুট ফিল্ড কন্ট্রোলারের তালিকা ---
  final emailController = TextEditingController(); // ইমেইল ফিল্ড
  final passController = TextEditingController();  // পাসওয়ার্ড ফিল্ড

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  /// সাইনআপ স্ক্রিনের মূল UI বিল্ড মেথড
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Create Account", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/signup.png"),
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
                  SizedBox(height: 60),
                  Icon(Icons.person_add_rounded, size: 80, color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    "Join the Family",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Start managing your expenses wisely",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                  ),
                  SizedBox(height: 50),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Email Address",
                            labelStyle: TextStyle(color: Colors.white70),
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
                            labelText: "Password",
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                    ),
                    onPressed: () async {
                      final email = emailController.text.trim();
                      final pass = passController.text.trim();

                      if (email.isEmpty || pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }

                      final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                      if (!emailOk) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please enter a valid email address"), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      if (pass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Password must be at least 6 characters"), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }

                      // Node C (Replicated Database) তে অ্যাকাউন্ট সেভ এবং পাসওয়ার্ড SHA-256 হ্যাশিং প্রসেস
                      final ok = await DistributedDB.signup(email, pass);

                      if (!context.mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Account created successfully!"), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Email already exists or error occurred"), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                    child: Text("SIGN UP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

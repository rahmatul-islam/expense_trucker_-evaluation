import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../database/distributed_db.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool biometricsEnabled = false;
  bool isBiometricsSupported = false;
  String selectedCurrency = "BDT (৳)";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Node C থেকে settings load (Replicated)
    final cur = await DistributedDB.getSetting('currency', 'BDT (৳)');
    final notif = await DistributedDB.getSetting('notifications_enabled', '1');
    final bio = await DistributedDB.getSetting('biometrics_enabled', '0');

    final auth = LocalAuthentication();
    bool supported = false;
    try {
      supported = await auth.canCheckBiometrics && await auth.isDeviceSupported();
    } catch (e) {
      debugPrint("Biometric check error: $e");
    }

    setState(() {
      selectedCurrency = cur;
      notificationsEnabled = notif == '1';
      biometricsEnabled = bio == '1';
      isBiometricsSupported = supported;
    });
  }

  Future<void> _exportToCSV() async {
    // Node A + B থেকে সব expenses নিয়ে CSV বানাও
    final expenses = await DistributedDB.getExpenses();
    List<List<dynamic>> rows = [];
    rows.add(["ID", "Title", "Amount", "Type", "Category", "Date", "Account", "Node"]);

    for (var e in expenses) {
      rows.add([
        e['id'], e['title'], e['amount'], e['type'],
        e['category'], e['date'], e['account'], e['node_id'] ?? 'unknown'
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/expenses_distributed_report.csv";
    final file = File(path);
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(path)], text: 'My Distributed Expenses Report');
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final auth = LocalAuthentication();
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (authenticated) {
          // Node C তে setting save
          await DistributedDB.setSetting('biometrics_enabled', '1');
          setState(() => biometricsEnabled = true);
        }
      } catch (e) {
        debugPrint("Biometric error: $e");
      }
    } else {
      await DistributedDB.setSetting('biometrics_enabled', '0');
      setState(() => biometricsEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Settings",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2940), Color(0xFF16213E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("Appearance"),
                _buildThemeTile(isDarkMode),
                const SizedBox(height: 20),

                _sectionLabel("Preferences"),
                _buildSettingTile(
                  Icons.monetization_on_outlined,
                  "Default Currency",
                  selectedCurrency,
                  onTap: _showCurrencyPicker,
                ),
                _buildSwitchTile(
                  Icons.notifications_none_rounded,
                  "Push Notifications",
                  "Get alerts for budgets and bills",
                  notificationsEnabled,
                      (v) async {
                    await DistributedDB.setSetting('notifications_enabled', v ? '1' : '0');
                    setState(() => notificationsEnabled = v);
                  },
                ),
                if (isBiometricsSupported)
                  _buildSwitchTile(
                    Icons.fingerprint_rounded,
                    "Biometric Login",
                    "Secure account access",
                    biometricsEnabled,
                    _toggleBiometrics,
                  ),
                const SizedBox(height: 20),

                _sectionLabel("Data Management"),
                _buildSettingTile(
                  Icons.file_download_outlined,
                  "Export Data (CSV)",
                  "Share your transaction history from all nodes",
                  onTap: _exportToCSV,
                ),
                _buildSettingTile(
                  Icons.delete_sweep_outlined,
                  "Reset All Data",
                  "Clear all transactions from all nodes",
                  color: Colors.redAccent,
                  onTap: () => _showResetDialog(context),
                ),
                const SizedBox(height: 20),

                // DDBMS Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storage_rounded, color: Color(0xFF6C63FF), size: 20),
                          SizedBox(width: 8),
                          Text("Distributed Database Info",
                              style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _dbInfoRow("Node A", "Current year expenses (Supabase)"),
                      _dbInfoRow("Node B", "Previous year expenses (Supabase)"),
                      _dbInfoRow("Node C", "Budgets, Settings, Users (Supabase)"),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Text("Version 4.0.0 — Distributed Edition",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dbInfoRow(String node, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(node,
                style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 15),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF8E7CFF),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12)),
    );
  }

  Widget _buildThemeTile(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: const Color(0xFF6C63FF)),
        ),
        title: const Text("Dark Mode",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        trailing: Switch(
          value: isDarkMode,
          onChanged: (value) async {
            themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            // Node C তে theme setting save
            await DistributedDB.setSetting('themeMode', value ? 'dark' : 'light');
          },
          activeThumbColor: const Color(0xFF6C63FF),
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, Color? color}) {
    Color iconColor = color ?? const Color(0xFF6C63FF);
    Color textColor = color ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        subtitle:
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle,
      bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle:
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6C63FF)),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 25),
            const Text("Select Currency",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 20),
            _currencyItem("BDT (৳)"),
            _currencyItem("USD (\$)"),
            _currencyItem("EUR (€)"),
            _currencyItem("INR (₹)"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _currencyItem(String currency) {
    bool isSelected = selectedCurrency == currency;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        title: Text(currency,
            style: TextStyle(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal)),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
            : null,
        onTap: () async {
          setState(() => selectedCurrency = currency);
          // Node C তে currency save
          await DistributedDB.setSetting('currency', currency);
          currencyNotifier.value = _getCurrencySymbol(currency);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  String _getCurrencySymbol(String currencyString) {
    if (currencyString.contains('৳')) return '৳';
    if (currencyString.contains('\$')) return '\$';
    if (currencyString.contains('€')) return '€';
    if (currencyString.contains('₹')) return '₹';
    return '৳';
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Reset All Data?",
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            "This will delete all transactions from Node A and Node B, and all budgets from Node C. Cannot be undone!",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL",
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              // Node A reset
              await DistributedDB.deleteAllExpenses('A');
              // Node B reset
              await DistributedDB.deleteAllExpenses('B');
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("All data reset from all nodes"),
                    backgroundColor: Colors.green),
              );
            },
            child: const Text("RESET",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import '../app_theme.dart';
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

    String csvData = ListToCsvConverter().convert(rows);
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
          options: AuthenticationOptions(biometricOnly: true),
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
    AppTheme.watch(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Settings",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bg0, AppTheme.bg1, AppTheme.bg2],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("Appearance"),
                _buildThemePicker(),
                SizedBox(height: 20),

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
                SizedBox(height: 20),

                _sectionLabel("Account"),
                _buildSettingTile(
                  Icons.lock_reset_rounded,
                  "Change Password",
                  "Update your account password",
                  onTap: _showChangePasswordDialog,
                ),
                SizedBox(height: 20),

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
                SizedBox(height: 20),

                // DDBMS Info Card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage_rounded, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text("Distributed Database Info",
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                      SizedBox(height: 12),
                      _dbInfoRow("Node A", "Current year expenses (Supabase)"),
                      _dbInfoRow("Node B", "Previous year expenses (Supabase)"),
                      _dbInfoRow("Node C", "Budgets, Settings, Users (Supabase)"),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                Center(
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
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(node,
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(desc,
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 10, bottom: 15),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: AppTheme.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12)),
    );
  }

  Widget _buildThemePicker() {
    final cur = AppTheme.paletteNotifier.value;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.palette_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Color Theme",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(AppTheme.palettes[cur].name,
                        style:
                        TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(AppTheme.palettes.length, (i) {
              final p = AppTheme.palettes[i];
              final selected = i == cur;
              return GestureDetector(
                onTap: () {
                  AppTheme.select(i); // রং সঙ্গে সঙ্গে বদলায় এবং Node C-তে সেভ হয়
                  setState(() {});
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [p.primary, p.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                          BoxShadow(
                            color: p.primary.withValues(alpha: 0.5),
                            blurRadius: 12,
                          )
                        ]
                            : [],
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                    SizedBox(height: 6),
                    Text(p.name,
                        style: TextStyle(
                            color: selected ? Colors.white : Colors.white54,
                            fontSize: 11)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, Color? color}) {
    Color iconColor = color ?? AppTheme.primary;
    Color textColor = color ?? Colors.white;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        subtitle:
        Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.white24),
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle,
      bool value, Function(bool) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle:
        Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary),
      ),
    );
  }

  Widget _pwField(TextEditingController c, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: true,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white54),
          enabledBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool busy = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text("Change Password",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pwField(oldCtrl, "Current password"),
                _pwField(newCtrl, "New password (min 6 characters)"),
                _pwField(confirmCtrl, "Confirm new password"),
                if (error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(error ?? '',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                final oldP = oldCtrl.text.trim();
                final newP = newCtrl.text.trim();
                final conf = confirmCtrl.text.trim();
                if (oldP.isEmpty || newP.isEmpty || conf.isEmpty) {
                  setLocal(() => error = "Please fill all fields");
                  return;
                }
                if (newP.length < 6) {
                  setLocal(() =>
                  error = "New password must be at least 6 characters");
                  return;
                }
                if (newP != conf) {
                  setLocal(() => error = "New passwords do not match");
                  return;
                }
                setLocal(() {
                  busy = true;
                  error = null;
                });
                final result =
                await DistributedDB.changePassword(oldP, newP);
                if (!dialogContext.mounted) return;
                if (result == null) {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Password changed successfully"),
                        backgroundColor: Colors.green),
                  );
                } else {
                  setLocal(() {
                    busy = false;
                    error = result;
                  });
                }
              },
              child: Text("SAVE",
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 25),
            Text("Select Currency",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            SizedBox(height: 20),
            _currencyItem("BDT (৳)"),
            _currencyItem("USD (\$)"),
            _currencyItem("EUR (€)"),
            _currencyItem("INR (₹)"),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _currencyItem(String currency) {
    bool isSelected = selectedCurrency == currency;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        title: Text(currency,
            style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.white,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal)),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: AppTheme.primary)
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
        backgroundColor: Color(0xFF1E1E1E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text("Reset All Data?",
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            "This will delete all transactions from Node A and Node B (and their copies in Node C). Cannot be undone!",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL",
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
                SnackBar(
                    content: Text("All data reset from all nodes"),
                    backgroundColor: Colors.green),
              );
            },
            child: Text("RESET",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

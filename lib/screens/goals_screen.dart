// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../database/distributed_db.dart';
import '../main.dart';

/// সেভিংস গোলস স্ক্রিন - নতুন সঞ্চয় লক্ষ্য তৈরি করা, লক্ষ্যমাত্রায় টাকা যোগ করা এবং অগ্রগতি পর্যবেক্ষণ করার স্ক্রিন
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // --- স্টেট ভেরিয়েবলসমূহ ---
  List<Map<String, dynamic>> goals = []; // সঞ্চয় লক্ষ্যের তালিকা (Node C থেকে)
  bool isLoading = true; // ডাটা লোডিং স্টেট

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// Node C (Replicated Database) থেকে সেভিংস লক্ষ্য ডাটা লোড করা
  Future<void> loadData() async {
    if (mounted) setState(() => isLoading = true);
    final data = await DistributedDB.getGoals();
    if (!mounted) return;
    setState(() {
      goals = data;
      isLoading = false;
    });
  }

  /// নোটিফিকেশন স্ন্যাকবার প্রদর্শন মেথড
  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  /// টাকা ফরম্যাটিং হেলপার
  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  /// ইনপুট টেক্সট ফিল্ড ডেকোরেশন হেলপার
  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white10)),
    );
  }

  // ─────────────────────────────────────────────
  // ডায়ালগ ও অ্যাকশনসমূহ
  // ─────────────────────────────────────────────
  
  /// নতুন সঞ্চয় লক্ষ্য তৈরি করার পপ-আপ ডায়ালগ (Node C-তে সেভ হয়)
  void _showAddGoalDialog() {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    bool busy = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text("New Savings Goal",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: Colors.white),
                decoration: _fieldDeco("Goal name (e.g. New phone)"),
              ),
              SizedBox(height: 15),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: _fieldDeco("Target amount"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: busy
                  ? null
                  : () async {
                final title = titleCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text.trim());
                if (title.isEmpty || target == null || target <= 0) {
                  _toast("Enter a name and a target amount above 0", error: true);
                  return;
                }
                setLocal(() => busy = true);
                final ok = await DistributedDB.addGoal(title, target);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (ok) {
                  _toast("Goal created");
                  loadData();
                } else {
                  _toast("Could not save the goal", error: true);
                }
              },
              child: Text("SAVE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// নির্দিষ্ট সঞ্চয় লক্ষ্যে টাকা যোগ বা জমা করার পপ-আপ ডায়ালগ
  void _showAddMoneyDialog(Map<String, dynamic> goal) {
    final amountCtrl = TextEditingController();
    bool busy = false;
    final saved = (goal['saved_amount'] as num).toDouble();
    final target = (goal['target_amount'] as num).toDouble();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text("Add to \"${goal['title']}\"",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: _fieldDeco("Amount to add"),
              ),
              SizedBox(height: 10),
              Text("Remaining: ${_fmt((target - saved).clamp(0.0, double.infinity).toDouble())}",
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: busy
                  ? null
                  : () async {
                final add = double.tryParse(amountCtrl.text.trim());
                if (add == null || add <= 0) {
                  _toast("Enter an amount above 0", error: true);
                  return;
                }
                setLocal(() => busy = true);
                final ok = await DistributedDB.updateGoalSaved(
                    goal['id'], saved + add);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (ok) {
                  _toast(saved + add >= target
                      ? "Goal reached! 🎉"
                      : "Money added");
                  loadData();
                } else {
                  _toast("Could not update the goal", error: true);
                }
              },
              child: Text("ADD",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// সঞ্চয় লক্ষ্য মুছে ফেলার কনফার্মেশন ডায়ালগ
  void _confirmDelete(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text("Delete goal?",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text("\"${goal['title']}\" will be removed permanently.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final ok = await DistributedDB.deleteGoal(goal['id']);
                if (ok) {
                  _toast("Goal deleted");
                  loadData();
                } else {
                  _toast("Could not delete the goal", error: true);
                }
              },
              child: Text("DELETE",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI উইজেটসমূহ
  // ─────────────────────────────────────────────
  
  /// কোনো সেভিংস গোল না থাকলে খালি অবস্থার উইজেট
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flag_rounded, size: 54, color: AppTheme.primary),
            ),
            SizedBox(height: 22),
            Text("No savings goals yet",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Set a target and track your progress,\none step at a time.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4)),
            SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _showAddGoalDialog,
              icon: Icon(Icons.add_rounded),
              label: Text("Create your first goal",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// প্রতিটি সঞ্চয় লক্ষ্যের প্রোগ্রেস বার এবং জমা করার বাটন সমৃদ্ধ কার্ড
  Widget _goalCard(Map<String, dynamic> g, String currency) {
    final title = (g['title'] ?? '').toString();
    final saved = (g['saved_amount'] as num).toDouble();
    final target = (g['target_amount'] as num).toDouble();
    final ratio = target > 0 ? saved / target : 0.0;
    final percent = ratio.clamp(0.0, 1.0);
    final done = target > 0 && saved >= target;
    final remaining = (target - saved).clamp(0.0, double.infinity).toDouble();
    final barColors = done
        ? [Colors.green, Colors.greenAccent.shade700]
        : [AppTheme.primary, AppTheme.secondary];

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
            color: done
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.emoji_events_rounded : Icons.flag_rounded,
                  color: done ? Colors.green : AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(g),
                icon: Icon(Icons.delete_outline_rounded, color: Colors.white38),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$currency ${_fmt(saved)} / $currency ${_fmt(target)}",
                  style: TextStyle(
                      color: done ? Colors.green : Colors.white,
                      fontWeight: FontWeight.bold)),
              Text("${(ratio * 100).clamp(0, 100).toStringAsFixed(0)}%",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: barColors),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                done
                    ? "Goal reached! 🎉"
                    : "$currency ${_fmt(remaining)} to go",
                style: TextStyle(
                    color: done ? Colors.green : Colors.white54, fontSize: 12),
              ),
              if (!done)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showAddMoneyDialog(g),
                  icon: Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: Text("Add money",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// মূল স্ক্রিন বিল্ড মেথড
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currency, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text("Savings Goals",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : goals.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                onRefresh: loadData,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: goals.length,
                  itemBuilder: (context, index) =>
                      _goalCard(goals[index], currency),
                ),
              ),
            ),
          ),
          floatingActionButton: goals.isEmpty
              ? null
              : FloatingActionButton.extended(
            onPressed: _showAddGoalDialog,
            backgroundColor: AppTheme.primary,
            elevation: 10,
            icon: Icon(Icons.add_rounded, color: Colors.white),
            label: Text("New Goal",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

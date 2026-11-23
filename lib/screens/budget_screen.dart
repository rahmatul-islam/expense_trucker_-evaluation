// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../database/distributed_db.dart';
import '../main.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Map<String, dynamic>> budgets = [];
  Map<String, double> categorySpent = {};
  final amountController = TextEditingController();
  String selectedCategory = "Food";
  bool isLoading = true;
  late DateTime month; // মাসের প্রথম দিন

  final List<String> categories = [
    "Food", "Transport", "Shopping", "Bills", "Health", "Entertainment", "Other"
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    loadData();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  String get _monthKey => "${month.month}_${month.year}";

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  String _money(double v) => NumberFormat('#,##0.##').format(v);

  void _changeMonth(int delta) {
    if (delta > 0 && _isCurrentMonth) return; // ভবিষ্যতের মাসে যাওয়া যাবে না
    setState(() => month = DateTime(month.year, month.month + delta));
    loadData();
  }

  Future<void> loadData() async {
    if (mounted) setState(() => isLoading = true);
    // Node C থেকে budgets (Replicated)
    final bData = await DistributedDB.getBudgets(_monthKey);
    // Node A + B থেকে expenses (Horizontal Fragment)
    final eData = await DistributedDB.getExpenses();

    // budget মাসিক, তাই শুধু বাছাই করা মাসের খরচ গুনতে হবে
    final monthPrefix =
        "${month.year}-${month.month.toString().padLeft(2, '0')}";

    final Map<String, double> spent = {};
    for (var e in eData) {
      if (e['type'] == "Expense" &&
          (e['date'] ?? '').toString().startsWith(monthPrefix)) {
        final cat = (e['category'] ?? "Other").toString();
        spent[cat] = (spent[cat] ?? 0) + (e['amount'] as num).toDouble();
      }
    }

    // সীমার সবচেয়ে কাছে যেটা, সেটা আগে দেখাবে
    double ratio(Map<String, dynamic> b) {
      final limit = (b['limit_amount'] as num).toDouble();
      return limit > 0 ? (spent[b['category']] ?? 0) / limit : 0;
    }

    final sorted = List<Map<String, dynamic>>.from(bData);
    sorted.sort((a, b) => ratio(b).compareTo(ratio(a)));

    if (!mounted) return;
    setState(() {
      budgets = sorted;
      categorySpent = spent;
      isLoading = false;
    });
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_bus_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Health':
        return Icons.medical_services_rounded;
      case 'Entertainment':
        return Icons.movie_creation_outlined;
      default:
        return Icons.category_rounded;
    }
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'Food':
        return Color(0xFFFF9F43);
      case 'Transport':
        return Color(0xFF54A0FF);
      case 'Shopping':
        return Color(0xFFFF6B9D);
      case 'Bills':
        return Color(0xFFFF5252);
      case 'Health':
        return Color(0xFF1DD1A1);
      case 'Entertainment':
        return Color(0xFFA55EEA);
      default:
        return Color(0xFF9E9E9E);
    }
  }

  // ─────────────────────────────────────────────
  // UI অংশ
  // ─────────────────────────────────────────────
  Widget _monthSelector() {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: Icon(Icons.chevron_left_rounded, color: Colors.white),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
            icon: Icon(Icons.chevron_right_rounded,
                color: _isCurrentMonth ? Colors.white24 : Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String cur) {
    double totalLimit = 0;
    double totalSpent = 0;
    for (final b in budgets) {
      totalLimit += (b['limit_amount'] as num).toDouble();
      totalSpent += categorySpent[b['category']] ?? 0;
    }
    final left = totalLimit - totalSpent;
    final over = left < 0;
    final ratio = totalLimit > 0 ? totalSpent / totalLimit : 0.0;

    Widget stat(String label, String value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
            SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.35),
            AppTheme.secondary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This month at a glance",
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          SizedBox(height: 14),
          Row(
            children: [
              stat("Budget", "$cur ${_money(totalLimit)}", Colors.white),
              stat("Spent", "$cur ${_money(totalSpent)}", Colors.white),
              stat(over ? "Over by" : "Left",
                  "$cur ${_money(left.abs())}",
                  over ? Colors.redAccent : Colors.greenAccent),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: Colors.white12,
              color: over ? Colors.redAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(Map<String, dynamic> b, String cur) {
    final cat = (b['category'] ?? 'Other').toString();
    final limit = (b['limit_amount'] as num).toDouble();
    final spent = categorySpent[cat] ?? 0;
    final percent = limit > 0 ? (spent / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final isOver = spent > limit;
    final isWarn = !isOver && limit > 0 && spent >= limit * 0.8;
    final color = _categoryColor(cat);
    final left = limit - spent;

    final Color statusColor = isOver
        ? Colors.redAccent
        : (isWarn ? Colors.amber : Colors.white54);
    final String statusText = isOver
        ? "Over by $cur ${_money(spent - limit)}"
        : isWarn
        ? "Almost at your limit · $cur ${_money(left)} left"
        : "$cur ${_money(left)} left";

    return GestureDetector(
      onTap: () => _showBudgetDialog(category: cat, limit: limit),
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: isOver
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_categoryIcon(cat), color: color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(cat,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(cat),
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.white38),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$cur ${_money(spent)} / $cur ${_money(limit)}",
                    style: TextStyle(
                        color: isOver
                            ? Colors.redAccent
                            : (isWarn ? Colors.amber : Colors.white),
                        fontWeight: FontWeight.bold)),
                Text("${(percent * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
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
                      gradient: LinearGradient(
                        colors: isOver
                            ? [Colors.redAccent, Colors.red]
                            : isWarn
                            ? [Colors.amber, Colors.orange]
                            : [AppTheme.primary, AppTheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                if (isOver || isWarn) ...[
                  Icon(Icons.warning_amber_rounded,
                      color: statusColor, size: 16),
                  SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: (isOver || isWarn)
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
                Text("Tap to edit",
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              child: Icon(Icons.savings_rounded,
                  size: 54, color: AppTheme.primary),
            ),
            SizedBox(height: 22),
            Text("No budgets for this month",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Set a limit for a category and\nwe'll warn you before you overspend.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4)),
          ],
        ),
      ),
    );
  }

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
            title: Text("Monthly Budgets",
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
              child: Column(
                children: [
                  _monthSelector(),
                  Expanded(
                    child: isLoading
                        ? Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary))
                        : budgets.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                      onRefresh: loadData,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                        itemCount: budgets.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _summaryCard(currency);
                          return _budgetCard(budgets[index - 1], currency);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showBudgetDialog(),
            backgroundColor: AppTheme.primary,
            elevation: 10,
            icon: Icon(Icons.add_task_rounded, color: Colors.white),
            label: Text("Set Budget",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // ডায়ালগ
  // ─────────────────────────────────────────────
  void _confirmDelete(String cat) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text("Remove budget?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
            "The $cat budget for ${DateFormat('MMMM yyyy').format(month)} will be removed.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await DistributedDB.deleteBudget(cat, _monthKey);
              if (ok) {
                _toast("Budget removed");
                loadData();
              } else {
                _toast("Could not remove the budget", error: true);
              }
            },
            child: Text("REMOVE",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog({String? category, double? limit}) {
    final editing = category != null;
    selectedCategory = category ?? selectedCategory;
    amountController.text = limit == null
        ? ''
        : (limit == limit.roundToDouble()
        ? limit.toInt().toString()
        : limit.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text(editing ? "Edit Budget" : "Set Category Budget",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    dropdownColor: Color(0xFF1E1E1E),
                    isExpanded: true,
                    style: TextStyle(color: Colors.white),
                    items: categories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: editing
                        ? null
                        : (v) => setDialogState(() => selectedCategory = v!),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter limit amount",
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("CANCEL", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim());
                if (amt == null || amt <= 0) {
                  _toast("Enter an amount above 0", error: true);
                  return;
                }
                // Node C তে budget save (Replicated)
                final ok = await DistributedDB.setBudget(
                    selectedCategory, amt, _monthKey);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (ok) {
                  _toast("Budget saved");
                  loadData();
                } else {
                  _toast("Could not save the budget", error: true);
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
}
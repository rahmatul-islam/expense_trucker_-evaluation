
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/distributed_db.dart';
import '../main.dart';
import 'add_expense.dart';
import 'login_screen.dart';
import 'stats_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import 'distribution_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (mounted) setState(() => isLoading = true);
    // Node A + Node B থেকে একসাথে data আনা হচ্ছে
    final data = await DistributedDB.getExpenses();
    if (!mounted) return;
    setState(() {
      expenses = data;
      isLoading = false;
    });
  }

  // ─────────────────────────────────────────────
  // হিসাব ও ছোট helper
  // ─────────────────────────────────────────────
  Map<String, double> getStats() {
    double total = 0;
    double income = 0;
    double expense = 0;
    for (var e in expenses) {
      final amt = (e['amount'] as num).toDouble();
      if (e['type'] == "Expense") {
        expense += amt;
        total -= amt;
      } else {
        income += amt;
        total += amt;
      }
    }
    return {'total': total, 'income': income, 'expense': expense};
  }

  String _money(double v) => NumberFormat('#,##0.##').format(v);

  String _prettyDate(dynamic raw) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw?.toString() ?? '';
    }
  }

  String _niceName(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final local = email.split('@').first;
    if (local.isEmpty) return 'User';
    return local[0].toUpperCase() + local.substring(1);
  }

  int _countNode(String letter) => expenses
      .where((e) => DistributedDB.nodeLetter(e['node_id']) == letter)
      .length;

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
      case 'Salary':
        return Icons.payments_rounded;
      case 'Business':
        return Icons.business_center_rounded;
      case 'Gift':
        return Icons.redeem_rounded;
      case 'Investment':
        return Icons.trending_up_rounded;
      case 'Transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // currency বদলালে সঙ্গে সঙ্গে পুরো স্ক্রিন আপডেট হবে
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, cur, _) => _buildScaffold(context, cur),
    );
  }

  Widget _buildScaffold(BuildContext context, String cur) {
    final stats = getStats();
    final email = DistributedDB.currentEmail;
    final name = _niceName(email);

    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
                ),
              ),
              accountName: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(email ?? 'Biometric login'),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: AssetImage("images/boy1.jpg"),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerTile(Icons.home_rounded, "Dashboard",
                          () => Navigator.pop(context)),
                  _drawerTile(Icons.add_box_rounded, "Add Transaction", () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddExpense()))
                        .then((_) => loadData());
                  }),
                  _drawerTile(Icons.pie_chart_rounded, "Analysis", () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StatsScreen()));
                  }),
                  _drawerTile(Icons.savings_rounded, "Budgets", () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetScreen()));
                  }),
                  _drawerTile(Icons.hub_rounded, "Distribution", () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DistributionScreen()))
                        .then((_) => loadData());
                  }),
                  _drawerTile(Icons.settings_rounded, "Settings", () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                  }),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            _drawerTile(Icons.logout_rounded, "Logout", () {
              DistributedDB.currentEmail = null;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            }, color: Colors.redAccent),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/onboard1.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.menu_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          const Text("Welcome back,",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // Distribution Dashboard-এ যাওয়ার shortcut
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const DistributionScreen()))
                              .then((_) => loadData());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.hub_rounded,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Main Balance Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                          const Color(0xFF6C63FF).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text("Current Balance",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$cur ${_money(stats['total']!)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(
                                Icons.arrow_downward_rounded,
                                "Income",
                                "$cur${_money(stats['income']!)}",
                                Colors.greenAccent),
                            Container(
                                width: 1, height: 40, color: Colors.white24),
                            _statItem(
                                Icons.arrow_upward_rounded,
                                "Expense",
                                "$cur${_money(stats['expense']!)}",
                                Colors.redAccent),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // কোন node-এ কত row আছে (এই মুহূর্তে লোড হওয়া ডেটা থেকে)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _nodePill('A', _countNode('A')),
                    const SizedBox(width: 10),
                    _nodePill('B', _countNode('B')),
                  ],
                ),

                // কোনো node না পেলে সতর্কবার্তা
                ValueListenableBuilder<QueryTrace?>(
                  valueListenable: DistributedDB.lastTrace,
                  builder: (context, trace, _) {
                    final failed =
                        trace?.nodes.where((n) => !n.ok).toList() ?? [];
                    if (failed.isEmpty) return const SizedBox.shrink();
                    final names = failed.map((n) => "Node ${n.node}").join(", ");
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.orangeAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "$names পাওয়া যাচ্ছে না — আংশিক ডেটা দেখানো হচ্ছে",
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Transactions Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Activity",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: loadData,
                        child: const Text("Refresh",
                            style: TextStyle(color: Color(0xFF8E7CFF))),
                      )
                    ],
                  ),
                ),

                // Transactions List (নিচে টানলে refresh হবে)
                Expanded(child: _buildList(cur)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddExpense()))
              .then((_) => loadData());
        },
        label: const Text("NEW TRANSACTION",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildList(String cur) {
    // প্রথমবার লোড হচ্ছে
    if (isLoading && expenses.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      onRefresh: loadData,
      child: expenses.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text("No transactions yet",
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      )
          : ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final item = expenses[index];
          final isExpense = item['type'] == "Expense";
          final accent = isExpense ? Colors.redAccent : Colors.greenAccent;
          final letter = DistributedDB.nodeLetter(item['node_id']);
          final amount = (item['amount'] as num).toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(_categoryIcon(item['category']),
                          color: accent),
                    ),
                    title: Text(item['title'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    subtitle: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "${item['category'] ?? ''} · ${item['account'] ?? ''}",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color:
                                Colors.white.withValues(alpha: 0.7),
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _nodeChip(letter),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isExpense ? '-' : '+'} $cur${_money(amount)}",
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(_prettyDate(item['date']),
                            style: TextStyle(
                                color:
                                Colors.white.withValues(alpha: 0.5),
                                fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ছোট widget
  // ─────────────────────────────────────────────
  Widget _nodeChip(String letter) {
    if (letter.isEmpty) return const SizedBox.shrink();
    final color = DistributedDB.nodeColor(letter);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text("NODE $letter",
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _nodePill(String letter, int count) {
    final color = DistributedDB.nodeColor(letter);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text("Node $letter · $count row",
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap,
      {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color.withValues(alpha: 0.7)),
      title: Text(title,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

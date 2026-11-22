
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../database/distributed_db.dart';
import '../main.dart';
import 'add_expense.dart';
import 'login_screen.dart';
import 'stats_screen.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'distribution_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;
  final TextEditingController searchCtrl = TextEditingController();
  String filterType = 'All'; // All | Expense | Income

  // অ্যানিমেশনের হিসাব
  final Set<String> _animatedKeys = {}; // যেগুলোর entrance অ্যানিমেশন হয়ে গেছে
  Set<String> _knownKeys = {}; // আগের বার লোড হওয়া লেনদেন
  Set<String> _freshKeys = {}; // একদম নতুন যোগ হওয়া (কিছুক্ষণ উজ্জ্বল থাকবে)
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _keyOf(Map<String, dynamic> e) => '${e['node_id']}-${e['id']}';

  Future<void> loadData() async {
    if (mounted) setState(() => isLoading = true);
    // Node A + Node B থেকে একসাথে data আনা হচ্ছে
    final data = await DistributedDB.getExpenses();
    if (!mounted) return;

    // আগের লোডে ছিল না, এখন আছে → একদম নতুন লেনদেন
    final keys = data.map(_keyOf).toSet();
    Set<String> fresh = {};
    if (!_firstLoad) fresh = keys.difference(_knownKeys);
    _knownKeys = keys;
    _firstLoad = false;

    setState(() {
      expenses = data;
      isLoading = false;
      _freshKeys = fresh;
    });

    if (fresh.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _freshKeys = {});
      });
    }
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

  /// শেষ ৭ দিনের দৈনিক খরচ (পুরনো → নতুন), খরচ না থাকা দিনে ০
  List<double> _last7DaysExpense() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<double> out = [];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      double sum = 0;
      for (final e in expenses) {
        if (e['type'] == 'Expense' && (e['date'] ?? '').toString() == key) {
          sum += (e['amount'] as num).toDouble();
        }
      }
      out.add(sum);
    }
    return out;
  }

  /// search আর filter প্রয়োগ করা তালিকা
  List<Map<String, dynamic>> get filtered {
    final q = searchCtrl.text.trim().toLowerCase();
    return expenses.where((e) {
      if (filterType != 'All' && e['type'] != filterType) return false;
      if (q.isEmpty) return true;
      final hay =
      '${e['title'] ?? ''} ${e['category'] ?? ''} ${e['account'] ?? ''} ${e['amount'] ?? ''} ${e['date'] ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
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

  /// প্রতিটা category-র নিজস্ব রং
  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'Food':
        return Color(0xFFFF9F43); // কমলা
      case 'Transport':
        return Color(0xFF54A0FF); // নীল
      case 'Shopping':
        return Color(0xFFFF6B9D); // গোলাপি
      case 'Bills':
        return Color(0xFFFF5252); // লাল
      case 'Health':
        return Color(0xFF1DD1A1); // সবুজাভ
      case 'Entertainment':
        return Color(0xFFA55EEA); // বেগুনি
      case 'Salary':
        return Color(0xFF2ECC71); // সবুজ
      case 'Business':
        return Color(0xFF00CEC9); // টিল
      case 'Gift':
        return Color(0xFFFD79A8); // হালকা গোলাপি
      case 'Investment':
        return Color(0xFFFECA57); // হলুদ
      case 'Transfer':
        return Color(0xFF95A5A6); // ধূসর
      default:
        return Color(0xFF9E9E9E);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : AppTheme.primary,
    ));
  }

  /// অন্য স্ক্রিন খুলে, ফিরে এলে data আবার আনে
  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => loadData());
  }

  // ─────────────────────────────────────────────
  // Delete (swipe) ও Undo
  // ─────────────────────────────────────────────
  Future<bool> _deleteItem(Map<String, dynamic> item) async {
    try {
      final ok = await DistributedDB.deleteExpense(
        (item['id'] as num).toInt(),
        (item['date'] ?? '').toString(),
        nodeId: item['node_id']?.toString(),
      );
      if (!ok) _snack('Delete হয়নি — Debug Console দেখুন', error: true);
      return ok;
    } catch (e) {
      _snack(e.toString(), error: true);
      return false;
    }
  }

  void _showUndo(Map<String, dynamic> item) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text('"${item['title'] ?? ''}" মুছে ফেলা হয়েছে'),
      backgroundColor: Color(0xFF2A2A3A),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
      duration: Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: AppTheme.secondary,
        onPressed: () async {
          try {
            await DistributedDB.addExpense(
              title: (item['title'] ?? '').toString(),
              amount: (item['amount'] as num).toDouble(),
              type: (item['type'] ?? 'Expense').toString(),
              category: (item['category'] ?? 'Other').toString(),
              date: (item['date'] ?? '').toString(),
              account: (item['account'] ?? 'Cash').toString(),
              isRecurring: item['is_recurring'] == true,
            );
          } catch (e) {
            _snack(e.toString(), error: true);
          }
          loadData();
        },
      ),
    ));
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
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
    final list = filtered;

    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        backgroundColor: Color(0xFF121212),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.bg0],
                ),
              ),
              accountName:
              Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(email ?? 'Biometric login'),
              currentAccountPicture: CircleAvatar(
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
                    _open(AddExpense());
                  }),
                  _drawerTile(Icons.pie_chart_rounded, "Analysis", () {
                    Navigator.pop(context);
                    _open(StatsScreen());
                  }),
                  _drawerTile(Icons.assessment_rounded, "Monthly Report", () {
                    Navigator.pop(context);
                    _open(ReportScreen());
                  }),
                  _drawerTile(Icons.savings_rounded, "Budgets", () {
                    Navigator.pop(context);
                    _open(BudgetScreen());
                  }),
                  _drawerTile(Icons.flag_rounded, "Savings Goals", () {
                    Navigator.pop(context);
                    _open(GoalsScreen());
                  }),
                  _drawerTile(Icons.hub_rounded, "Distribution", () {
                    Navigator.pop(context);
                    _open(DistributionScreen());
                  }),
                  _drawerTile(Icons.settings_rounded, "Settings", () {
                    Navigator.pop(context);
                    _open(SettingsScreen());
                  }),
                ],
              ),
            ),
            Divider(color: Colors.white10),
            _drawerTile(Icons.logout_rounded, "Logout", () {
              DistributedDB.currentEmail = null;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => LoginScreen()));
            }, color: Colors.redAccent),
            SizedBox(height: 20),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
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
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: loadData,
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _topBar(name),
                        SizedBox(height: 14),
                        _balanceCard(cur, stats),
                        SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _nodePill('A', _countNode('A')),
                            SizedBox(width: 10),
                            _nodePill('B', _countNode('B')),
                          ],
                        ),
                        _nodeWarning(),
                        _searchArea(list.length),
                      ],
                    ),
                  ),
                  if (isLoading && expenses.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        ),
                      ),
                    )
                  else if (list.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40, bottom: 120),
                        child: Column(
                          children: [
                            Icon(
                              expenses.isEmpty
                                  ? Icons.receipt_long_rounded
                                  : Icons.search_off_rounded,
                              size: 54,
                              color: Colors.white24,
                            ),
                            SizedBox(height: 12),
                            Text(
                              expenses.isEmpty
                                  ? "No transactions yet"
                                  : "কিছু পাওয়া যায়নি",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _tile(list[index], cur, index),
                          childCount: list.length,
                          // delete/নতুন আইটেমের পরেও সঠিক আইটেমের state ধরে রাখে
                          findChildIndexCallback: (Key key) {
                            if (key is ValueKey<String>) {
                              final i = list
                                  .indexWhere((e) => _keyOf(e) == key.value);
                              return i < 0 ? null : i;
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _open(AddExpense()),
        label: Text("NEW TRANSACTION",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        icon: Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // উপরের অংশ
  // ─────────────────────────────────────────────
  Widget _roundIcon(IconData icon) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _topBar(String name) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: _roundIcon(Icons.menu_rounded),
            ),
          ),
          Column(
            children: [
              Text("Welcome back,",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(name,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          GestureDetector(
            onTap: () => _open(DistributionScreen()),
            child: _roundIcon(Icons.hub_rounded),
          ),
        ],
      ),
    );
  }

  /// সংখ্যাটা পুরনো মান থেকে নতুন মানে গুনে গুনে পৌঁছায়
  Widget _countText(double value, String prefix, TextStyle style) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        // অ্যানিমেশন চলার সময় পূর্ণসংখ্যা, শেষে আসল মান (দশমিকসহ)
        final shown = (v - value).abs() < 0.005
            ? _money(value)
            : NumberFormat('#,##0').format(v);
        return Text('$prefix$shown', style: style);
      },
    );
  }

  Widget _balanceCard(String cur, Map<String, double> stats) {
    final week = _last7DaysExpense();
    final weekTotal = week.fold<double>(0, (a, b) => a + b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, 24, 24, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Text("Current Balance",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _countText(
                stats['total']!,
                '$cur ',
                TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.arrow_downward_rounded, "Income",
                    stats['income']!, cur, Colors.greenAccent),
                Container(width: 1, height: 40, color: Colors.white24),
                _statItem(Icons.arrow_upward_rounded, "Expense",
                    stats['expense']!, cur, Colors.redAccent),
              ],
            ),
            SizedBox(height: 18),
            Divider(color: Colors.white24, height: 1),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("শেষ ৭ দিনের খরচ",
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('$cur${_money(weekTotal)}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            _sparkline(week),
          ],
        ),
      ),
    );
  }

  /// Balance কার্ডের ভেতরের ছোট trend রেখা
  Widget _sparkline(List<double> data) {
    double maxV = 0;
    for (final v in data) {
      if (v > maxV) maxV = v;
    }
    if (maxV == 0) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Text("এই সপ্তাহে কোনো খরচ নেই",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      );
    }
    return SizedBox(
      height: 56,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxV * 1.25,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i]),
              ],
              isCurved: true,
              color: Colors.white,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// কোনো node না পেলে সতর্কবার্তা
  Widget _nodeWarning() {
    return ValueListenableBuilder<QueryTrace?>(
      valueListenable: DistributedDB.lastTrace,
      builder: (context, trace, _) {
        final failed = trace?.nodes.where((n) => !n.ok).toList() ?? [];
        if (failed.isEmpty) return SizedBox.shrink();
        final names = failed.map((n) => "Node ${n.node}").join(", ");
        return Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border:
            Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "$names পাওয়া যাচ্ছে না — আংশিক ডেটা দেখানো হচ্ছে",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Search ও filter
  // ─────────────────────────────────────────────
  Widget _searchArea(int resultCount) {
    final active = searchCtrl.text.trim().isNotEmpty || filterType != 'All';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Activity",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: loadData,
                icon: Icon(Icons.refresh_rounded, color: AppTheme.secondary),
              ),
            ],
          ),
          SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'নাম, category বা টাকা খুঁজুন…',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () {
                    searchCtrl.clear();
                    setState(() {});
                  },
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              _filterChip('All'),
              SizedBox(width: 8),
              _filterChip('Expense'),
              SizedBox(width: 8),
              _filterChip('Income'),
              Spacer(),
              if (active)
                Text('$resultCount টি ফলাফল',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = filterType == label;
    return GestureDetector(
      onTap: () => setState(() => filterType = label),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
          selected ? AppTheme.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // একটা লেনদেন (swipe করে delete, ট্যাপ করে edit)
  // ─────────────────────────────────────────────
  Widget _tile(Map<String, dynamic> item, String cur, int index) {
    final k = _keyOf(item);
    // প্রথমবার দেখা গেলে এবং শুরুর দিকের ১০টির মধ্যে হলে তবেই entrance অ্যানিমেশন
    final animate = _animatedKeys.add(k) && index < 10;
    final fresh = _freshKeys.contains(k);

    final isExpense = item['type'] == "Expense";
    final amountColor = isExpense ? Colors.redAccent : Colors.greenAccent;
    final catColor = _categoryColor(item['category']?.toString());
    final letter = DistributedDB.nodeLetter(item['node_id']);
    final amount = (item['amount'] as num).toDouble();

    return _FadeSlideIn(
      key: ValueKey(k),
      animate: animate,
      delayIndex: index,
      child: Padding(
        padding: EdgeInsets.only(bottom: 15),
        child: Dismissible(
          key: ValueKey('d-$k'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 26),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.delete_rounded, color: Colors.white, size: 28),
          ),
          // আগে database থেকে মোছা হয়, সফল হলেই তবে তালিকা থেকে সরে
          confirmDismiss: (direction) => _deleteItem(item),
          onDismissed: (direction) {
            setState(() {
              expenses.removeWhere((e) => _keyOf(e) == k);
            });
            _showUndo(item);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  // একদম নতুন লেনদেন কয়েক সেকেন্ড থিমের রঙে উজ্জ্বল থাকে
                  color: fresh
                      ? AppTheme.primary.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: fresh
                        ? AppTheme.secondary
                        : Colors.white.withValues(alpha: 0.15),
                    width: fresh ? 1.5 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => _open(AddExpense(expenseData: item)),
                    leading: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                          _categoryIcon(item['category']?.toString()),
                          color: catColor),
                    ),
                    title: Text(
                      item['title'] ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    subtitle: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "${item['category'] ?? ''} · ${item['account'] ?? ''}",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 8),
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
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          _prettyDate(item['date']),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ছোট widget
  // ─────────────────────────────────────────────
  Widget _nodeChip(String letter) {
    if (letter.isEmpty) return SizedBox.shrink();
    final color = DistributedDB.nodeColor(letter);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          SizedBox(width: 6),
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

  Widget _statItem(IconData icon, String label, double value, String cur,
      Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
        SizedBox(height: 5),
        _countText(
          value,
          cur,
          TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// তালিকার আইটেম নিচ থেকে ভেসে আসার অ্যানিমেশন
// ═══════════════════════════════════════════════════════════
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final bool animate;
  final int delayIndex;

  const _FadeSlideIn({
    super.key,
    required this.child,
    required this.animate,
    required this.delayIndex,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 450),
    );
    final curved =
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = curved;
    _slide =
        Tween<Offset>(begin: Offset(0, 0.25), end: Offset.zero).animate(curved);

    if (widget.animate) {
      final delay = (widget.delayIndex < 9 ? widget.delayIndex : 9) * 70;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1; // আগে দেখানো বা দূরের আইটেম: অ্যানিমেশন ছাড়াই দেখাও
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

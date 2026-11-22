
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../database/distributed_db.dart';
import '../main.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> all = [];
  bool loading = true;
  late DateTime month; // মাসের প্রথম দিন

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    // Node A + Node B থেকে সব ডেটা এনে মাস অনুযায়ী ভাগ করা হচ্ছে
    final data = await DistributedDB.getExpenses();
    if (!mounted) return;
    setState(() {
      all = data;
      loading = false;
    });
  }

  String _prefix(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _rowsOf(DateTime m) {
    final p = _prefix(m);
    return all
        .where((e) => (e['date'] ?? '').toString().startsWith(p))
        .toList();
  }

  double _sum(List<Map<String, dynamic>> rows, String type) => rows
      .where((e) => e['type'] == type)
      .fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());

  String _money(double v) => NumberFormat('#,##0.##').format(v);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, cur, _) {
        final rows = _rowsOf(month);
        final prevRows = _rowsOf(DateTime(month.year, month.month - 1));
        final income = _sum(rows, 'Income');
        final expense = _sum(rows, 'Expense');
        final prevExpense = _sum(prevRows, 'Expense');
        final net = income - expense;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text("Monthly Report",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: AppTheme.background),
            child: SafeArea(
              child: loading
                  ? Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary))
                  : RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20),
                  children: [
                    _monthSelector(),
                    SizedBox(height: 16),
                    if (rows.isEmpty)
                      _card(
                        child: Column(
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 46, color: Colors.white24),
                            SizedBox(height: 10),
                            Text("এই মাসে কোনো লেনদেন নেই",
                                style:
                                TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          _miniStat("Income", income, Colors.greenAccent,
                              cur, Icons.arrow_downward_rounded),
                          SizedBox(width: 10),
                          _miniStat("Expense", expense, Colors.redAccent,
                              cur, Icons.arrow_upward_rounded),
                          SizedBox(width: 10),
                          _miniStat(
                              "Net",
                              net,
                              net >= 0
                                  ? AppTheme.secondary
                                  : Colors.orangeAccent,
                              cur,
                              Icons.savings_rounded),
                        ],
                      ),
                      SizedBox(height: 14),
                      _compareCard(expense, prevExpense),
                      _sectionLabel("Daily Spending"),
                      SizedBox(height: 10),
                      _card(child: _dailyChart(rows)),
                      _sectionLabel("Top Categories"),
                      SizedBox(height: 10),
                      _categoryCard(rows, expense, cur),
                      _sectionLabel("Insights"),
                      SizedBox(height: 10),
                      _insightsCard(rows, expense, cur),
                    ],
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // অংশগুলো
  // ─────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 6),
      child: Text(text,
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _monthSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1)),
            icon: Icon(Icons.chevron_left_rounded, color: Colors.white),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _isCurrentMonth
                ? null
                : () => setState(
                    () => month = DateTime(month.year, month.month + 1)),
            icon: Icon(Icons.chevron_right_rounded,
                color: _isCurrentMonth ? Colors.white24 : Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
      String label, double value, Color color, String cur, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                SizedBox(width: 6),
                Text(label,
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
            SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$cur${_money(value)}',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareCard(double expense, double prev) {
    String text;
    Color color;
    IconData icon;
    if (prev == 0) {
      text = 'আগের মাসের তুলনা করার মতো ডেটা নেই';
      color = Colors.white54;
      icon = Icons.info_outline_rounded;
    } else {
      final change = (expense - prev) / prev * 100;
      final up = change >= 0;
      text =
      'আগের মাসের তুলনায় খরচ ${up ? 'বেড়েছে' : 'কমেছে'} ${change.abs().toStringAsFixed(0)}%';
      color = up ? Colors.redAccent : Colors.greenAccent;
      icon = up ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    }
    return _card(
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _dailyChart(List<Map<String, dynamic>> rows) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final Map<int, double> daily = {};
    for (final e in rows) {
      if (e['type'] != 'Expense') continue;
      final d = DateTime.tryParse((e['date'] ?? '').toString());
      if (d == null) continue;
      daily[d.day] = (daily[d.day] ?? 0) + (e['amount'] as num).toDouble();
    }
    double maxDaily = 0;
    for (final v in daily.values) {
      if (v > maxDaily) maxDaily = v;
    }
    if (maxDaily == 0) {
      return SizedBox(
        height: 80,
        child: Center(
            child: Text("এই মাসে কোনো খরচ নেই",
                style: TextStyle(color: Colors.white38))),
      );
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxDaily * 1.2,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final d = value.toInt();
                  if (d == 1 || d % 5 == 0) {
                    return Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('$d',
                          style:
                          TextStyle(color: Colors.white38, fontSize: 10)),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: List.generate(daysInMonth, (i) {
            final day = i + 1;
            return BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: daily[day] ?? 0,
                  color: AppTheme.primary,
                  width: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _categoryCard(
      List<Map<String, dynamic>> rows, double expense, String cur) {
    final Map<String, double> totals = {};
    for (final e in rows) {
      if (e['type'] != 'Expense') continue;
      final c = (e['category'] ?? 'Other').toString();
      totals[c] = (totals[c] ?? 0) + (e['amount'] as num).toDouble();
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _card(
        child: Text("এই মাসে কোনো খরচ নেই",
            style: TextStyle(color: Colors.white38)),
      );
    }

    final top = entries.take(5).toList();
    return _card(
      child: Column(
        children: List.generate(top.length, (i) {
          final e = top[i];
          final percent = expense > 0 ? e.value / expense : 0.0;
          final color = Colors.primaries[i % Colors.primaries.length];
          return Padding(
            padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(e.key,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      '$cur${_money(e.value)}  ·  ${(percent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _insightsCard(
      List<Map<String, dynamic>> rows, double expense, String cur) {
    final now = DateTime.now();
    final daysCounted =
    _isCurrentMonth ? now.day : DateTime(month.year, month.month + 1, 0).day;
    final avgPerDay = daysCounted > 0 ? expense / daysCounted : 0.0;

    Map<String, dynamic>? biggest;
    for (final e in rows) {
      if (e['type'] != 'Expense') continue;
      if (biggest == null ||
          (e['amount'] as num) > (biggest['amount'] as num)) {
        biggest = e;
      }
    }

    final nodeA =
        rows.where((e) => DistributedDB.nodeLetter(e['node_id']) == 'A').length;
    final nodeB =
        rows.where((e) => DistributedDB.nodeLetter(e['node_id']) == 'B').length;

    return _card(
      child: Column(
        children: [
          _insightRow(Icons.receipt_long_rounded, "মোট লেনদেন",
              "${rows.length} টি"),
          _insightRow(Icons.calendar_today_rounded, "গড় দৈনিক খরচ",
              '$cur${_money(avgPerDay)}'),
          _insightRow(
            Icons.local_fire_department_rounded,
            "সবচেয়ে বড় খরচ",
            biggest == null
                ? "—"
                : '${biggest['title'] ?? ''} ($cur${_money((biggest['amount'] as num).toDouble())})',
          ),
          Divider(color: Colors.white12, height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _nodeBadge('A', nodeA),
              SizedBox(width: 10),
              _nodeBadge('B', nodeB),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "এই মাসের ডেটা কোন node থেকে এসেছে",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondary, size: 18),
          SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white60, fontSize: 13)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeBadge(String letter, int count) {
    final color = DistributedDB.nodeColor(letter);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text("Node $letter · $count",
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/distributed_db.dart';
import '../main.dart';

/// স্ট্যাটস/অ্যানালাইসিস স্ক্রিন - ক্যাটাগরি অনুযায়ী খরচের পাই-চার্ট এবং গত ৭ দিনের দৈনিক ট্রেন্ড লাইন-চার্ট দেখানোর স্ক্রিন
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // --- স্টেট ভেরিয়েবলসমূহ ---
  List<Map<String, dynamic>> categoryStats = []; // ক্যাটাগরি অনুযায়ী সংগৃহীত ডাটা
  List<Map<String, dynamic>> dailyStats = [];    // দৈনিক হিসাবের ডাটা
  String selectedType = "Expense"; // Expense অথবা Income
  bool isLoading = true; // ডাটা লোডিং স্টেট

  @override
  void initState() {
    super.initState();
    loadAllStats();
  }

  /// Node A + Node B থেকে প্রাপ্ত ডাটা দিয়ে ক্যাটাগরি ও দৈনিক ট্রেন্ড ক্যালকুলেট করার মেথড
  Future<void> loadAllStats() async {
    setState(() => isLoading = true);
    // Node A + Node B এর data মিলিয়ে হিসাব হচ্ছে
    final cData = await DistributedDB.getCategoryStats(selectedType);
    final dData = await DistributedDB.getDailyStats(selectedType, 7);
    if (!mounted) return;
    setState(() {
      categoryStats = cData;
      dailyStats = dData;
      isLoading = false;
    });
  }

  /// স্ক্রিনের মূল UI লেআউট মেথড
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
            title: Text("Analysis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bg0,
                  AppTheme.bg1,
                  AppTheme.bg2,
                ],
              ),
            ),
            child: SafeArea(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // টাইপ টগল বাটন (Expense / Income)
                    Row(
                      children: [
                        _toggleBtn("Expense", Colors.redAccent),
                        SizedBox(width: 15),
                        _toggleBtn("Income", Colors.greenAccent),
                      ],
                    ),
                    SizedBox(height: 30),

                    _sectionLabel("Weekly Trend"),
                    SizedBox(height: 15),
                    _buildLineChart(currency),

                    SizedBox(height: 40),

                    _sectionLabel("Category Breakdown"),
                    SizedBox(height: 15),
                    _buildPieChartSection(),

                    SizedBox(height: 40),

                    _sectionLabel("Details"),
                    SizedBox(height: 15),
                    _buildCategoryList(currency),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// সেকশন হেডারের লেবেল উইজেট
  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  /// গত ৭ দিনের ট্রেন্ড চার্ট তৈরির মেথড (LineChart)
  Widget _buildLineChart(String currency) {
    if (dailyStats.isEmpty) {
      return _emptyBox("Not enough data for trend");
    }

    return Container(
      height: 200,
      padding: EdgeInsets.only(top: 20, right: 20, left: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Color(0xFF1E1E1E),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    "$currency ${touchedSpot.y.toInt()}",
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= dailyStats.length) return SizedBox();
                  String day = dailyStats[idx]['day'];
                  try {
                    DateTime dt = DateTime.parse(day);
                    return Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('E').format(dt), style: TextStyle(color: Colors.white38, fontSize: 10)),
                    );
                  } catch (e) {
                    return SizedBox();
                  }
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: dailyStats.length == 1
                  ? [
                FlSpot(0, (dailyStats[0]['total'] as num).toDouble()),
                FlSpot(1, (dailyStats[0]['total'] as num).toDouble())
              ]
                  : List.generate(
                  dailyStats.length,
                      (i) => FlSpot(i.toDouble(), (dailyStats[i]['total'] as num).toDouble())),
              isCurved: true,
              color: selectedType == "Expense" ? Colors.redAccent : Colors.greenAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: dailyStats.length == 1),
              belowBarData: BarAreaData(
                show: true,
                color: (selectedType == "Expense" ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ক্যাটাগরি ভিত্তিক শতকরা খরচের পাই-চার্ট (PieChart) সেকশন উইজেট
  Widget _buildPieChartSection() {
    if (categoryStats.isEmpty) {
      return _emptyBox("No data available");
    }

    final totalAmount = categoryStats.fold<num>(0, (sum, e) => sum + (e['total'] as num));

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: List.generate(categoryStats.length, (i) {
                    final item = categoryStats[i];
                    final value = (item['total'] as num).toDouble();
                    final percent = totalAmount > 0 ? (value / totalAmount * 100).toInt() : 0;
                    return PieChartSectionData(
                      color: Colors.primaries[i % Colors.primaries.length],
                      value: value,
                      title: "$percent%",
                      titleStyle: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      radius: 40,
                    );
                  }),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(categoryStats.length.clamp(0, 5), (i) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.primaries[i % Colors.primaries.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          categoryStats[i]['category'] ?? "Other",
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          SizedBox(width: 15),
        ],
      ),
    );
  }

  /// প্রতিটি ক্যাটাগরির বিস্তারিত টাকার পরিমাণ দেখানোর তালিকা
  Widget _buildCategoryList(String currency) {
    return Column(
      children: List.generate(categoryStats.length, (i) {
        final item = categoryStats[i];
        final color = Colors.primaries[i % Colors.primaries.length];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              SizedBox(width: 15),
              Text(item['category'] ?? "Other", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Spacer(),
              Text("$currency ${(item['total'] as num).toInt()}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
    );
  }

  /// ডাটা না থাকলে দেখানোর খালি কন্টেইনার
  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.white24))),
    );
  }

  /// Expense ও Income অপশন পরিবর্তনের টগল বাটন
  Widget _toggleBtn(String type, Color color) {
    bool isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedType = type);
          loadAllStats();
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

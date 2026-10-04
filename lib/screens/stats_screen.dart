import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../main.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final db = DatabaseHelper();
  List<Map<String, dynamic>> categoryStats = [];
  List<Map<String, dynamic>> dailyStats = [];
  String selectedType = "Expense";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAllStats();
  }

  Future<void> loadAllStats() async {
    setState(() => isLoading = true);
    final cData = await db.getCategoryStats(selectedType);
    final dData = await db.getDailyStats(selectedType, 7);
    setState(() {
      categoryStats = cData;
      dailyStats = dData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currency, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text("Analysis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A2940),
                  Color(0xFF16213E),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
            child: SafeArea(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type Toggle
                        Row(
                          children: [
                            _toggleBtn("Expense", Colors.redAccent),
                            const SizedBox(width: 15),
                            _toggleBtn("Income", Colors.greenAccent),
                          ],
                        ),
                        const SizedBox(height: 30),
    
                        _sectionLabel("Weekly Trend"),
                        const SizedBox(height: 15),
                        _buildLineChart(currency),
    
                        const SizedBox(height: 40),
    
                        _sectionLabel("Category Breakdown"),
                        const SizedBox(height: 15),
                        _buildPieChartSection(),
    
                        const SizedBox(height: 40),
                        
                        _sectionLabel("Details"),
                        const SizedBox(height: 15),
                        _buildCategoryList(currency),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
            ),
          ),
        );
      }
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildLineChart(String currency) {
    if (dailyStats.isEmpty) {
      return _emptyBox("Not enough data for trend");
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xFF1E1E1E),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    "$currency ${touchedSpot.y.toInt()}",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx < 0 || idx >= dailyStats.length) return const SizedBox();
                  String day = dailyStats[idx]['day'];
                  try {
                    DateTime dt = DateTime.parse(day);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('E').format(dt), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    );
                  } catch (e) {
                    return const SizedBox();
                  }
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: dailyStats.length == 1 
                ? [FlSpot(0, (dailyStats[0]['total'] as num).toDouble()), FlSpot(1, (dailyStats[0]['total'] as num).toDouble())]
                : List.generate(dailyStats.length, (i) => FlSpot(i.toDouble(), (dailyStats[i]['total'] as num).toDouble())),
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

  Widget _buildPieChartSection() {
    if (categoryStats.isEmpty) {
      return _emptyBox("No data available");
    }

    final totalAmount = categoryStats.fold<num>(0, (sum, e) => sum + (e['total'] as num));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          categoryStats[i]['category'] ?? "Other",
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String currency) {
    return Column(
      children: List.generate(categoryStats.length, (i) {
        final item = categoryStats[i];
        final color = Colors.primaries[i % Colors.primaries.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 15),
              Text(item['category'] ?? "Other", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text("$currency ${(item['total'] as num).toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }),
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.white24))),
    );
  }

  Widget _toggleBtn(String type, Color color) {
    bool isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedType = type);
          loadAllStats();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
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

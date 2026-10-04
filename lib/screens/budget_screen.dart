import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../main.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final db = DatabaseHelper();
  List<Map<String, dynamic>> budgets = [];
  Map<String, double> categorySpent = {};
  final amountController = TextEditingController();
  String selectedCategory = "Food";

  final List<String> categories = ["Food", "Transport", "Shopping", "Bills", "Health", "Entertainment", "Other"];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final month = "${DateTime.now().month}_${DateTime.now().year}";
    final bData = await db.getBudgets(month);
    final eData = await db.getExpenses();
    
    Map<String, double> spent = {};
    for (var e in eData) {
      if (e['type'] == "Expense") {
        String cat = e['category'] ?? "Other";
        spent[cat] = (spent[cat] ?? 0) + (e['amount'] as num).toDouble();
      }
    }

    setState(() {
      budgets = bData;
      categorySpent = spent;
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
            title: const Text("Monthly Budgets", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                colors: [
                  Color(0xFF1A2940),
                  Color(0xFF16213E),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: budgets.isEmpty
                        ? const Center(child: Text("No budgets set yet", style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: budgets.length,
                            itemBuilder: (context, index) {
                              final b = budgets[index];
                              final cat = b['category'];
                              final limit = (b['limit_amount'] as num).toDouble();
                              final spent = categorySpent[cat] ?? 0;
                              final percent = (spent / limit).clamp(0.0, 1.0);
                              final isOver = spent > limit;
    
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(cat, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text("$currency ${spent.toInt()} / $currency ${limit.toInt()}", 
                                          style: TextStyle(color: isOver ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
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
                                                  : [const Color(0xFF6C63FF), const Color(0xFF8E7CFF)],
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isOver ? Colors.redAccent : const Color(0xFF6C63FF)).withValues(alpha: 0.3),
                                                  blurRadius: 10,
                                                )
                                              ]
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isOver)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                            SizedBox(width: 5),
                                            Text("Budget Exceeded!", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddBudgetDialog,
            backgroundColor: const Color(0xFF6C63FF),
            elevation: 10,
            icon: const Icon(Icons.add_task_rounded, color: Colors.white),
            label: const Text("Set Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    );
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: const Text("Set Category Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), 
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF1E1E1E),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter limit amount",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = int.tryParse(amountController.text);
                if (amt != null) {
                  final month = "${DateTime.now().month}_${DateTime.now().year}";
                  await db.setBudget(selectedCategory, amt, month);
                  if (!context.mounted) return;
                  amountController.clear();
                  Navigator.pop(context);
                  loadData();
                }
              },
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

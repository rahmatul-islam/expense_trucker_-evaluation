// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:intl/intl.dart';
import '../database/distributed_db.dart';
import '../main.dart';

/// নতুন লেনদেন (Income / Expense) যোগ বা বিদ্যমান লেনদেন এডিট করার স্ক্রিন
class AddExpense extends StatefulWidget {
  final Map<String, dynamic>? expenseData; // এডিট মোডের ক্ষেত্রে বিদ্যমান তথ্য

  const AddExpense({super.key, this.expenseData});

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  // --- স্টেট ভেরিয়েবলসমূহ ---
  final titleController = TextEditingController(); // বিবরণ/টাইটেল কন্ট্রোলার
  final amountController = TextEditingController(); // টাকার পরিমাণ কন্ট্রোলার
  String selectedType = "Expense"; // Expense অথবা Income
  String selectedCategory = "Food"; // নির্বাচিত ক্যাটাগরি
  String selectedAccount = "Cash"; // নির্বাচিত একাউন্ট (Cash, Bank, bKash, Nagad)
  bool isRecurring = false; // প্রতি মাসে পুনরাবৃত্তি হবে কিনা
  DateTime selectedDate = DateTime.now(); // নির্বাচিত তারিখ
  bool isEditing = false; // এডিট মোড চালু কিনা
  int? editingId; // এডিটিং লেনদেনের আইডি
  List<Map<String, dynamic>> _history = []; // অটো-সাজেশনের জন্য পূর্বের লেনদেনসমূহ
  bool _saving = false; // ডাবল সেভ হওয়া ঠেকানোর ফ্ল্যাগ

  // ব্যয়ের ক্যাটাগরি এবং আইকন তালিকা
  final Map<String, IconData> expenseCategories = {
    "Food": Icons.restaurant_rounded,
    "Transport": Icons.directions_bus_rounded,
    "Shopping": Icons.shopping_bag_rounded,
    "Bills": Icons.receipt_long_rounded,
    "Health": Icons.medical_services_rounded,
    "Entertainment": Icons.movie_creation_outlined,
    "Other": Icons.category_rounded,
  };

  // আয়ের ক্যাটাগরি এবং আইকন তালিকা
  final Map<String, IconData> incomeCategories = {
    "Salary": Icons.payments_rounded,
    "Business": Icons.business_center_rounded,
    "Gift": Icons.redeem_rounded,
    "Investment": Icons.trending_up_rounded,
    "Other": Icons.account_balance_wallet_rounded,
  };

  // একাউন্ট টাইপসমূহ
  final List<String> accounts = ["Cash", "Bank", "bKash", "Nagad"];

  @override
  void initState() {
    super.initState();
    titleController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.expenseData == null) _loadHistory();
    // এডিট মোড হলে পূর্বের ডাটা লোড করা
    if (widget.expenseData != null) {
      isEditing = true;
      editingId = widget.expenseData!['id'];
      titleController.text = widget.expenseData!['title'] ?? "";
      amountController.text = (widget.expenseData!['amount'] ?? 0).toString();
      selectedType = widget.expenseData!['type'] ?? "Expense";
      selectedCategory = widget.expenseData!['category'] ?? "Food";
      selectedAccount = widget.expenseData!['account'] ?? "Cash";
      isRecurring = (widget.expenseData!['is_recurring'] ?? false) == true ||
          (widget.expenseData!['is_recurring'] ?? 0) == 1;
      selectedDate =
          DateTime.tryParse(widget.expenseData!['date'] ?? "") ?? DateTime.now();
    }
  }

  /// অটো-সাজেশনের জন্য পূর্বে জমা হওয়া লেনদেনের হিস্ট্রি ফেচ করা
  Future<void> _loadHistory() async {
    final data = await DistributedDB.getExpenses();
    if (!mounted) return;
    setState(() => _history = data);
  }

  /// টাইটেল ইনপুটের সাথে ম্যাচ করা আগের লেনদেনের অটো-সাজেশন তালিকা
  List<Map<String, dynamic>> get _suggestions {
    final q = titleController.text.trim().toLowerCase();
    if (q.isEmpty || isEditing) return [];
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final e in _history) {
      final t = (e['title'] ?? '').toString();
      final key = t.toLowerCase();
      if (key.isEmpty || key == q || !key.contains(q)) continue;
      if (seen.add(key)) out.add(e);
      if (out.length >= 4) break;
    }
    return out;
  }

  /// অটো-সাজেশন থেকে পছন্দমতো আইটেম সিলেক্ট করলে ফর্মে অ্যাপ্লাই করা
  void _applySuggestion(Map<String, dynamic> e) {
    final type = (e['type'] ?? 'Expense').toString();
    final cat = (e['category'] ?? '').toString();
    final acc = (e['account'] ?? '').toString();
    final cats = type == "Expense" ? expenseCategories : incomeCategories;
    setState(() {
      titleController.text = (e['title'] ?? '').toString();
      titleController.selection =
          TextSelection.collapsed(offset: titleController.text.length);
      selectedType = type == "Income" ? "Income" : "Expense";
      if (cats.containsKey(cat)) selectedCategory = cat;
      if (accounts.contains(acc)) selectedAccount = acc;
    });
  }

  /// দ্রুত নির্দিষ্ট পরিমাণ টাকা ইনপুট ফিল্ডে যোগ করার মেথড (যেমন: +100, +500)
  void _addAmount(double v) {
    final current = double.tryParse(amountController.text.trim()) ?? 0;
    final next = current + v;
    amountController.text =
    next == next.roundToDouble() ? next.toInt().toString() : next.toString();
    amountController.selection =
        TextSelection.collapsed(offset: amountController.text.length);
    setState(() {});
  }

  /// দুটি তারিখ একই দিন কিনা তা পরীক্ষা করার হেলপার
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// ক্যাটাগরি ভিত্তিক কালার রিটার্ন করার মেথড
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
      case 'Salary':
        return Color(0xFF2ECC71);
      case 'Business':
        return Color(0xFF00CEC9);
      case 'Gift':
        return Color(0xFFFD79A8);
      case 'Investment':
        return Color(0xFFFECA57);
      default:
        return Color(0xFF9E9E9E);
    }
  }

  /// কুয়িক চিপ বাটন (যেমন: Today, Yesterday) উইজেট
  Widget _quickChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.transparent : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  /// তারিখ নির্বাচনের জন্য পিক-আপ ক্যালেন্ডার দেখানোর মেথড
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primary,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  /// লেনদেন সেভ করার মেথড - তারিখ অনুযায়ী অটোমেটিকভাবে Node A (চলতি বছর) অথবা Node B (আগের বছর)-তে সেভ হয়
  void _saveData() async {
    final title = titleController.text.trim();
    final amountText = amountController.text.trim();
    if (_saving) return;
    if (title.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a description and an amount"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Amount must be greater than 0"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    _saving = true;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      bool ok = false;

      if (isEditing && editingId != null) {
        // Node A বা B তে update — তারিখ দেখে ফ্র্যাগমেন্টেশন অনুযায়ী সেভ হবে
        ok = await DistributedDB.updateExpense(
          id: editingId!,
          originalNodeId: widget.expenseData?['node_id']?.toString(),
          title: title,
          amount: amount,
          type: selectedType,
          category: selectedCategory,
          date: dateStr,
          account: selectedAccount,
          isRecurring: isRecurring,
        );
      } else {
        // Node A বা B তে add — তারিখ দেখে ফ্র্যাগমেন্টেশন অনুযায়ী সেভ হবে
        ok = await DistributedDB.addExpense(
          title: title,
          amount: amount,
          type: selectedType,
          category: selectedCategory,
          date: dateStr,
          account: selectedAccount,
          isRecurring: isRecurring,
        );
      }

      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Database এ save হয়নি! Debug Console দেখুন"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? "Transaction updated!" : "Transaction added!"),
            backgroundColor: AppTheme.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _saving = false;
    }
  }

  /// UI মেথড
  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    var activeCategories =
    selectedType == "Expense" ? expenseCategories : incomeCategories;

    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currency, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              isEditing ? "Edit Transaction" : "Add Transaction",
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Container(
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            "Enter Amount",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currency,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 50,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "0",
                                    hintStyle: TextStyle(color: Colors.white10),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final v in [100, 500, 1000, 5000])
                                _quickChip("+$v", false, () => _addAmount(v.toDouble())),
                              _quickChip("Clear", false, () {
                                amountController.clear();
                                setState(() {});
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _typeOption("Expense", Colors.redAccent),
                              SizedBox(width: 15),
                              _typeOption("Income", Colors.greenAccent),
                            ],
                          ),
                          SizedBox(height: 25),
                          _label("Description"),
                          _inputField(titleController, "e.g. Weekly Grocery", Icons.edit_note_rounded),
                          if (_suggestions.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _suggestions
                                    .map((e) => ActionChip(
                                  avatar: Icon(Icons.history_rounded,
                                      size: 16, color: AppTheme.primary),
                                  label: Text((e['title'] ?? '').toString(),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                  backgroundColor:
                                  Colors.white.withValues(alpha: 0.07),
                                  side: BorderSide(color: Colors.white10),
                                  onPressed: () => _applySuggestion(e),
                                ))
                                    .toList(),
                              ),
                            ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label("Account"),
                                    _dropdownField(
                                      accounts,
                                      selectedAccount,
                                          (v) => setState(() => selectedAccount = v!),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [_label("Date"), _datePickerField()],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              _quickChip(
                                "Today",
                                _isSameDay(selectedDate, DateTime.now()),
                                    () => setState(() => selectedDate = DateTime.now()),
                              ),
                              SizedBox(width: 10),
                              _quickChip(
                                "Yesterday",
                                _isSameDay(selectedDate,
                                    DateTime.now().subtract(Duration(days: 1))),
                                    () => setState(() => selectedDate =
                                    DateTime.now().subtract(Duration(days: 1))),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          _label("Category"),
                          SizedBox(
                            height: 50,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: activeCategories.entries
                                  .map((e) => _categoryChip(e.key, e.value))
                                  .toList(),
                            ),
                          ),
                          SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Recurring Transaction",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Repeat this every month",
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                  ),
                                ],
                              ),
                              Switch(
                                value: isRecurring,
                                onChanged: (v) => setState(() => isRecurring = v),
                                activeThumbColor: AppTheme.primary,
                              ),
                            ],
                          ),
                          SizedBox(height: 35),
                          ElevatedButton(
                            onPressed: _saveData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              minimumSize: Size(double.infinity, 65),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              elevation: 10,
                              shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                            ),
                            child: Text(
                              isEditing ? "UPDATE TRANSACTION" : "CONFIRM TRANSACTION",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Expense / Income টাইপ পরিবর্তন বাটন উইজেট
  Widget _typeOption(String type, Color color) {
    bool isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedType = type;
          selectedCategory = type == "Expense" ? "Food" : "Salary";
        }),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: Offset(0, 5))]
                : [],
          ),
          child: Center(
            child: Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ফিল্ড হেডারের লেবেল উইজেট
  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// ইনপুট টেক্সট ফিল্ড কাস্টম উইজেট
  Widget _inputField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white10),
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// একাউন্ট ড্রপডাউন চয়েস ফিল্ড
  Widget _dropdownField(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: Color(0xFF1E1E1E),
          isExpanded: true,
          style: TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// তারিখ নির্বাচনের কাস্টম বোতাম ফিল্ড
  Widget _datePickerField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM dd, yyyy').format(selectedDate),
              style: TextStyle(color: Colors.white),
            ),
            Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 18),
          ],
        ),
      ),
    );
  }

  /// ক্যাটাগরি নির্বাচনের আনুভূমিক চিপ বাটন
  Widget _categoryChip(String name, IconData icon) {
    bool isSelected = selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = name),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? _categoryColor(name) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _categoryColor(name)),
            SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

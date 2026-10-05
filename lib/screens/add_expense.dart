import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/distributed_db.dart';
import '../main.dart';

class AddExpense extends StatefulWidget {
  final Map<String, dynamic>? expenseData;

  const AddExpense({super.key, this.expenseData});

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  String selectedType = "Expense";
  String selectedCategory = "Food";
  String selectedAccount = "Cash";
  bool isRecurring = false;
  DateTime selectedDate = DateTime.now();
  bool isEditing = false;
  int? editingId;

  final Map<String, IconData> expenseCategories = {
    "Food": Icons.restaurant_rounded,
    "Transport": Icons.directions_bus_rounded,
    "Shopping": Icons.shopping_bag_rounded,
    "Bills": Icons.receipt_long_rounded,
    "Health": Icons.medical_services_rounded,
    "Entertainment": Icons.movie_creation_outlined,
    "Other": Icons.category_rounded,
  };

  final Map<String, IconData> incomeCategories = {
    "Salary": Icons.payments_rounded,
    "Business": Icons.business_center_rounded,
    "Gift": Icons.redeem_rounded,
    "Investment": Icons.trending_up_rounded,
    "Other": Icons.account_balance_wallet_rounded,
  };

  final List<String> accounts = ["Cash", "Bank", "bKash", "Nagad"];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _saveData() async {
    final title = titleController.text.trim();
    final amountText = amountController.text.trim();
    if (title.isEmpty || amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Amount must be greater than 0"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      bool ok = false;

      if (isEditing && editingId != null) {
        // Node A বা B তে update — তারিখ দেখে ঠিক হবে
        ok = await DistributedDB.updateExpense(
          id: editingId!,
          title: title,
          amount: amount,
          type: selectedType,
          category: selectedCategory,
          date: dateStr,
          account: selectedAccount,
          isRecurring: isRecurring,
        );
      } else {
        // Node A বা B তে add — তারিখ দেখে ঠিক হবে
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
            const SnackBar(
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
            backgroundColor: const Color(0xFF6C63FF),
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const Text(
                            "Enter Amount",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currency,
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 50,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: "0",
                                    hintStyle: TextStyle(color: Colors.white10),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.only(
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
                              const SizedBox(width: 15),
                              _typeOption("Income", Colors.greenAccent),
                            ],
                          ),
                          const SizedBox(height: 25),
                          _label("Description"),
                          _inputField(titleController, "e.g. Weekly Grocery", Icons.edit_note_rounded),
                          const SizedBox(height: 20),
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
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [_label("Date"), _datePickerField()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
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
                                activeThumbColor: const Color(0xFF6C63FF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 35),
                          ElevatedButton(
                            onPressed: _saveData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              minimumSize: const Size(double.infinity, 65),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              elevation: 10,
                              shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                            ),
                            child: Text(
                              isEditing ? "UPDATE TRANSACTION" : "CONFIRM TRANSACTION",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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

  Widget _typeOption(String type, Color color) {
    bool isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedType = type;
          selectedCategory = type == "Expense" ? "Food" : "Salary";
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))]
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white10),
          prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _dropdownField(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePickerField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
              style: const TextStyle(color: Colors.white),
            ),
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF6C63FF), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String name, IconData icon) {
    bool isSelected = selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 8),
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
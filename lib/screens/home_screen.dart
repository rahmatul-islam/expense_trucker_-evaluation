import 'dart:ui';
import 'package:flutter/material.dart';
import '../database/distributed_db.dart';
import 'add_expense.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> expenses = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    // Node A + Node B থেকে একসাথে data আনা হচ্ছে
    final data = await DistributedDB.getExpenses();
    if (!mounted) return;
    setState(() {
      expenses = data;
    });
  }

  Map<String, int> getStats() {
    int total = 0;
    int income = 0;
    int expense = 0;
    for (var e in expenses) {
      // Supabase থেকে amount দশমিকসহ আসে (500.0), তাই num দিয়ে নিতে হয়
      int amt = (e['amount'] as num).toInt();
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

  // "node_a" → "NODE A"
  String _nodeLabel(dynamic nodeId) {
    if (nodeId == null) return '';
    return nodeId.toString().toUpperCase().replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final stats = getStats();

    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
                ),
              ),
              accountName: Text("Rahmatul Islam Ratul", style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text("Rahmatul@gmail.com"),
              currentAccountPicture: CircleAvatar(
                backgroundImage: AssetImage("images/boy1.jpg"),
              ),
            ),
            _drawerTile(Icons.home_rounded, "Dashboard", () => Navigator.pop(context)),
            _drawerTile(Icons.add_box_rounded, "Add Transaction", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpense())).then((_) => loadData());
            }),
            const Spacer(),
            const Divider(color: Colors.white10),
            _drawerTile(Icons.logout_rounded, "Logout", () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                Colors.black.withOpacity(0.85),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.menu_rounded, color: Colors.white),
                          ),
                        ),
                      ),
                      const Column(
                        children: [
                          Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text("Ratul", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

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
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text("Current Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 10),
                        Text(
                          "৳ ${stats['total']}",
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(Icons.arrow_downward_rounded, "Income", "৳${stats['income']}", Colors.greenAccent),
                            Container(width: 1, height: 40, color: Colors.white24),
                            _statItem(Icons.arrow_upward_rounded, "Expense", "৳${stats['expense']}", Colors.redAccent),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Transactions Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Activity",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: loadData,
                        child: const Text("Refresh", style: TextStyle(color: Color(0xFF8E7CFF))),
                      )
                    ],
                  ),
                ),

                // Transactions List
                Expanded(
                  child: expenses.isEmpty
                      ? const Center(child: Text("No transactions yet", style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final item = expenses[index];
                      final isExpense = item['type'] == "Expense";
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isExpense ? Colors.redAccent : Colors.greenAccent).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                                    color: isExpense ? Colors.redAccent : Colors.greenAccent,
                                  ),
                                ),
                                title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                // কোন node থেকে data এসেছে সেটাও দেখানো হচ্ছে (demo-র জন্য)
                                subtitle: Text(
                                  "${item['type']} · ${_nodeLabel(item['node_id'])}",
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${isExpense ? '-' : '+'} ৳${(item['amount'] as num).toInt()}",
                                      style: TextStyle(
                                        color: isExpense ? Colors.redAccent : Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text("${item['date'] ?? ''}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpense())).then((_) => loadData());
        },
        label: const Text("NEW TRANSACTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.7)),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
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
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
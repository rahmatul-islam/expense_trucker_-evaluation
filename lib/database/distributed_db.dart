import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class DistributedDB {
  // ═══════════════════════════════════════════════
  // HORIZONTAL FRAGMENTATION LOGIC
  // চলতি বছর → Node A, আগের বছর → Node B
  // ═══════════════════════════════════════════════
  static String _getNodeForDate(String date) {
    try {
      final year = DateTime.parse(date).year;
      final currentYear = DateTime.now().year;
      return year >= currentYear ? 'A' : 'B';
    } catch (_) {
      return 'A';
    }
  }

  // ═══════════════════════════════════════════════
  // HEADERS
  // ═══════════════════════════════════════════════
  static Map<String, String> _headers(String key) => {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // ═══════════════════════════════════════════════
  // PASSWORD HASHING
  // ═══════════════════════════════════════════════
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ═══════════════════════════════════════════════
  // AUTH — Node C তে
  // ═══════════════════════════════════════════════
  static Future<bool> signup(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/users'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'email': email,
          'password_hash': _hashPassword(password),
        }),
      );
      print('SIGNUP → Node C | ${response.statusCode} | ${response.body}');
      return response.statusCode == 201;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.nodeCUrl}/rest/v1/users'
              '?email=eq.$email'
              '&password_hash=eq.${_hashPassword(password)}'
              '&select=id',
        ),
        headers: _headers(AppConfig.nodeCKey),
      );
      final data = jsonDecode(response.body) as List;
      return data.isNotEmpty;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // ADD EXPENSE — Horizontal Fragmentation
  // তারিখ দেখে Node A বা B তে পাঠাবে
  // ═══════════════════════════════════════════════
  static Future<bool> addExpense({
    required String title,
    required double amount,
    required String type,
    required String category,
    required String date,
    String account = 'Cash',
    bool isRecurring = false,
  }) async {
    try {
      final node = _getNodeForDate(date);
      final url = node == 'A' ? AppConfig.nodeAUrl : AppConfig.nodeBUrl;
      final key = node == 'A' ? AppConfig.nodeAKey : AppConfig.nodeBKey;

      final response = await http.post(
        Uri.parse('$url/rest/v1/expenses'),
        headers: _headers(key),
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date,
          'account': account,
          'is_recurring': isRecurring,
          'node_id': 'node_${node.toLowerCase()}',
        }),
      );

      print('ADD → Node $node | ${response.statusCode} | ${response.body}');

      // Vertical Fragment — Node C তে core fields কপি
      if (response.statusCode == 201) {
        final created = jsonDecode(response.body);
        final refId = created is List ? created[0]['id'] : created['id'];
        await _saveVerticalFragment(refId, amount, category, date, node);
      }

      return response.statusCode == 201;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // VERTICAL FRAGMENT — Node C তে core fields save
  // ═══════════════════════════════════════════════
  static Future<void> _saveVerticalFragment(
      dynamic refId,
      double amount,
      String category,
      String date,
      String nodeSource,
      ) async {
    try {
      final r = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/expense_core'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'expense_ref_id': refId,
          'amount': amount,
          'category': category,
          'date': date,
          'node_source': 'node_${nodeSource.toLowerCase()}',
        }),
      );
      print('CORE → Node C | ${r.statusCode} | ${r.body}');
    } catch (e) {
      print('DB ERROR (core): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // GET ALL EXPENSES — Node A + Node B একসাথে
  // ═══════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('${AppConfig.nodeAUrl}/rest/v1/expenses?order=date.desc'),
          headers: _headers(AppConfig.nodeAKey),
        ),
        http.get(
          Uri.parse('${AppConfig.nodeBUrl}/rest/v1/expenses?order=date.desc'),
          headers: _headers(AppConfig.nodeBKey),
        ),
      ]);

      final listA = jsonDecode(results[0].body) as List;
      final listB = jsonDecode(results[1].body) as List;

      final all = [...listA, ...listB];
      all.sort((a, b) {
        final dateA = a['date'] ?? '';
        final dateB = b['date'] ?? '';
        return dateB.compareTo(dateA);
      });

      return all.cast<Map<String, dynamic>>();
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // UPDATE EXPENSE
  // ═══════════════════════════════════════════════
  static Future<bool> updateExpense({
    required int id,
    required String title,
    required double amount,
    required String type,
    required String category,
    required String date,
    String account = 'Cash',
    bool isRecurring = false,
  }) async {
    try {
      final node = _getNodeForDate(date);
      final url = node == 'A' ? AppConfig.nodeAUrl : AppConfig.nodeBUrl;
      final key = node == 'A' ? AppConfig.nodeAKey : AppConfig.nodeBKey;

      final response = await http.patch(
        Uri.parse('$url/rest/v1/expenses?id=eq.$id'),
        headers: _headers(key),
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date,
          'account': account,
          'is_recurring': isRecurring,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE EXPENSE
  // ═══════════════════════════════════════════════
  static Future<bool> deleteExpense(int id, String date) async {
    try {
      final node = _getNodeForDate(date);
      final url = node == 'A' ? AppConfig.nodeAUrl : AppConfig.nodeBUrl;
      final key = node == 'A' ? AppConfig.nodeAKey : AppConfig.nodeBKey;

      final response = await http.delete(
        Uri.parse('$url/rest/v1/expenses?id=eq.$id'),
        headers: _headers(key),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE ALL — Reset (Node A বা B)
  // ═══════════════════════════════════════════════
  static Future<void> deleteAllExpenses(String node) async {
    try {
      final url = node == 'A' ? AppConfig.nodeAUrl : AppConfig.nodeBUrl;
      final key = node == 'A' ? AppConfig.nodeAKey : AppConfig.nodeBKey;
      await http.delete(
        Uri.parse('$url/rest/v1/expenses?id=gte.0'),
        headers: _headers(key),
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════
  // BUDGETS — Node C তে (Replicated)
  // ═══════════════════════════════════════════════
  static Future<bool> setBudget(
      String category, double limit, String month) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/budgets'),
        headers: {
          ..._headers(AppConfig.nodeCKey),
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({
          'category': category,
          'limit_amount': limit,
          'month': month,
          'user_id': 1,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBudgets(String month) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/budgets?month=eq.$month'),
        headers: _headers(AppConfig.nodeCKey),
      );
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // SETTINGS — Node C তে (Replicated)
  // ═══════════════════════════════════════════════
  static Future<String> getSetting(String key, String defaultValue) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/settings?key=eq.$key'),
        headers: _headers(AppConfig.nodeCKey),
      );
      final data = jsonDecode(response.body) as List;
      if (data.isNotEmpty) return data[0]['value'] as String;
      return defaultValue;
    } catch (e) {
      print('DB ERROR: $e');
      return defaultValue;
    }
  }

  static Future<bool> setSetting(String key, String value) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/settings'),
        headers: {
          ..._headers(AppConfig.nodeCKey),
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({'key': key, 'value': value}),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // STATS
  // ═══════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getCategoryStats(
      String type) async {
    try {
      final expenses = await getExpenses();
      final filtered = expenses.where((e) => e['type'] == type).toList();

      final Map<String, double> categoryTotals = {};
      for (var e in filtered) {
        final cat = e['category'] ?? 'Other';
        final amt = (e['amount'] as num).toDouble();
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
      }

      final list = categoryTotals.entries
          .map((e) => {'category': e.key, 'total': e.value})
          .toList();
      list.sort((a, b) =>
          (b['total'] as double).compareTo(a['total'] as double));
      return list;
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // DAILY STATS — শেষ N দিনের trend (Node A + B মিলিয়ে)
  // ═══════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getDailyStats(
      String type, int days) async {
    try {
      final expenses = await getExpenses();
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1));
      final Map<String, double> dayTotals = {};

      for (var e in expenses) {
        if (e['type'] != type) continue;
        final dateStr = (e['date'] ?? '').toString();
        final dt = DateTime.tryParse(dateStr);
        if (dt == null || dt.isBefore(cutoff)) continue;
        final amt = (e['amount'] as num).toDouble();
        dayTotals[dateStr] = (dayTotals[dateStr] ?? 0) + amt;
      }

      final keys = dayTotals.keys.toList()..sort();
      return keys.map((k) => {'day': k, 'total': dayTotals[k]!}).toList();
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAccountBalances() async {
    try {
      final expenses = await getExpenses();
      final Map<String, double> balances = {};

      for (var e in expenses) {
        final account = e['account'] ?? 'Cash';
        final amt = (e['amount'] as num).toDouble();
        final isIncome = e['type'] == 'Income';
        balances[account] =
            (balances[account] ?? 0) + (isIncome ? amt : -amt);
      }

      return balances.entries
          .map((e) => {'account': e.key, 'balance': e.value})
          .toList();
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // 2PC — ACCOUNT TRANSFER (Distributed Transaction)
  // ═══════════════════════════════════════════════
  static Future<bool> transferBetweenAccounts({
    required String fromAccount,
    required String toAccount,
    required double amount,
    required String date,
  }) async {
    // Phase 1: PREPARE
    bool nodeAReady = false;
    bool nodeBReady = false;

    try {
      final checkA = await http.get(
        Uri.parse('${AppConfig.nodeAUrl}/rest/v1/expenses?limit=1'),
        headers: _headers(AppConfig.nodeAKey),
      );
      nodeAReady = checkA.statusCode == 200;
    } catch (_) {}

    try {
      final checkB = await http.get(
        Uri.parse('${AppConfig.nodeBUrl}/rest/v1/expenses?limit=1'),
        headers: _headers(AppConfig.nodeBKey),
      );
      nodeBReady = checkB.statusCode == 200;
    } catch (_) {}

    // Phase 2: COMMIT বা ROLLBACK
    if (nodeAReady && nodeBReady) {
      try {
        await addExpense(
          title: 'Transfer out → $toAccount',
          amount: amount,
          type: 'Expense',
          category: 'Transfer',
          date: date,
          account: fromAccount,
        );
        await addExpense(
          title: 'Transfer in ← $fromAccount',
          amount: amount,
          type: 'Income',
          category: 'Transfer',
          date: date,
          account: toAccount,
        );
        return true;
      } catch (_) {
        return false;
      }
    } else {
      return false;
    }
  }
} // ← DistributedDB class শেষ

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

// ═══════════════════════════════════════════════════════════
// সাহায্যকারী class (Dashboard ও Query trace এর জন্য)
// ═══════════════════════════════════════════════════════════

/// কোনো node বন্ধ থাকলে (সিমুলেশন) এই exception ছোঁড়া হয়
class NodeDownException implements Exception {
  final String message;
  NodeDownException(this.message);
  @override
  String toString() => message;
}

/// একটা query-তে একটা node কী করল
class NodeTrace {
  final String node;
  final bool ok;
  final int ms;
  final int rows;
  final String note;
  const NodeTrace({
    required this.node,
    required this.ok,
    required this.ms,
    required this.rows,
    required this.note,
  });
}

/// একটা পুরো query-র হিসাব (সব node মিলিয়ে)
class QueryTrace {
  final String label;
  final DateTime time;
  final List<NodeTrace> nodes;
  final int mergedRows;
  const QueryTrace({
    required this.label,
    required this.time,
    required this.nodes,
    required this.mergedRows,
  });
  bool get hasFailure => nodes.any((n) => !n.ok);
}

/// Dashboard-এ একটা node-এর অবস্থা
class NodeStatus {
  final String node;
  final String state; // online | offline | simulated
  final int pingMs;
  final Map<String, int> counts;
  const NodeStatus({
    required this.node,
    required this.state,
    required this.pingMs,
    required this.counts,
  });
}

class _Fetch {
  final List<Map<String, dynamic>> rows;
  final NodeTrace trace;
  _Fetch(this.rows, this.trace);
}

// ═══════════════════════════════════════════════════════════
// মূল class
// ═══════════════════════════════════════════════════════════
class DistributedDB {
  // ─────────────────────────────────────────────
  // গ্লোবাল অবস্থা
  // ─────────────────────────────────────────────

  /// যে node গুলো "বন্ধ" ধরা হচ্ছে (ডেমোর জন্য সিমুলেশন)
  static final ValueNotifier<Set<String>> simulatedDown =
  ValueNotifier<Set<String>>(<String>{});

  /// সর্বশেষ getExpenses() query-র হিসাব
  static final ValueNotifier<QueryTrace?> lastTrace =
  ValueNotifier<QueryTrace?>(null);

  /// এখন যে ইউজার লগইন করে আছে
  static String? _currentEmail;
  static dynamic currentUserId; // লগইন করা ইউজারের id (users টেবিল থেকে)

  static String? get currentEmail => _currentEmail;

  /// null দিলে (লগআউট) user id-ও আপনা-আপনি মুছে যায়
  static set currentEmail(String? v) {
    _currentEmail = v;
    if (v == null) currentUserId = null;
  }

  /// সব query-তে ব্যবহারের জন্য — লগইন না থাকলে '0' (কিছুই মিলবে না)
  static String get _uid => currentUserId?.toString() ?? '0';

  static bool isNodeDown(String node) => simulatedDown.value.contains(node);

  static void setNodeDown(String node, bool down) {
    final next = Set<String>.from(simulatedDown.value);
    if (down) {
      next.add(node);
    } else {
      next.remove(node);
    }
    simulatedDown.value = next;
  }

  // ─────────────────────────────────────────────
  // Node সংক্রান্ত helper
  // ─────────────────────────────────────────────
  static String _url(String node) {
    if (node == 'A') return AppConfig.nodeAUrl;
    if (node == 'B') return AppConfig.nodeBUrl;
    return AppConfig.nodeCUrl;
  }

  static String _key(String node) {
    if (node == 'A') return AppConfig.nodeAKey;
    if (node == 'B') return AppConfig.nodeBKey;
    return AppConfig.nodeCKey;
  }

  static Map<String, String> _headers(String key) => {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  /// "node_a" → "A"
  static String nodeLetter(dynamic nodeId) {
    final s = (nodeId ?? '').toString().toLowerCase();
    if (s.endsWith('_a')) return 'A';
    if (s.endsWith('_b')) return 'B';
    if (s.endsWith('_c')) return 'C';
    return '';
  }

  static Color nodeColor(String node) {
    switch (node) {
      case 'A':
        return const Color(0xFF4DA3FF);
      case 'B':
        return const Color(0xFFFFA24D);
      case 'C':
        return const Color(0xFF2EC4B6);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

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
    if (isNodeDown('C')) {
      print('SIGNUP skipped → Node C বন্ধ (সিমুলেশন)');
      return false;
    }
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
    if (isNodeDown('C')) {
      print('LOGIN skipped → Node C বন্ধ (সিমুলেশন)');
      return false;
    }
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.nodeCUrl}/rest/v1/users'
              '?email=eq.${Uri.encodeQueryComponent(email)}'
              '&password_hash=eq.${_hashPassword(password)}'
              '&select=id',
        ),
        headers: _headers(AppConfig.nodeCKey),
      );
      final data = jsonDecode(response.body) as List;
      final ok = data.isNotEmpty;
      if (ok) {
        currentUserId = data[0]['id'];
        currentEmail = email;
      }
      return ok;
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
    final node = _getNodeForDate(date);
    if (isNodeDown(node)) {
      throw NodeDownException(
          'Node $node এখন বন্ধ (সিমুলেশন) — এই তারিখের ডেটা সেভ করা যাচ্ছে না');
    }

    try {
      final response = await http.post(
        Uri.parse('${_url(node)}/rest/v1/expenses'),
        headers: _headers(_key(node)),
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'type': type,
          'category': category,
          'date': date,
          'account': account,
          'is_recurring': isRecurring,
          'node_id': 'node_${node.toLowerCase()}',
          'user_id': _uid,
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
    if (isNodeDown('C')) {
      print('CORE skipped → Node C বন্ধ (সিমুলেশন)');
      return;
    }
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
          'user_id': _uid,
        }),
      );
      print('CORE → Node C | ${r.statusCode} | ${r.body}');
    } catch (e) {
      print('DB ERROR (core): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // GET ALL EXPENSES — Node A + Node B একসাথে
  // (প্রতিটা node-এর সাড়া ও সময় lastTrace-এ জমা হয়)
  // ═══════════════════════════════════════════════
  static Future<_Fetch> _fetchExpenses(String node) async {
    if (isNodeDown(node)) {
      return _Fetch(
        [],
        NodeTrace(node: node, ok: false, ms: 0, rows: 0, note: 'বন্ধ (সিমুলেশন)'),
      );
    }
    final sw = Stopwatch()..start();
    try {
      final r = await http
          .get(
        Uri.parse('${_url(node)}/rest/v1/expenses?user_id=eq.$_uid&order=date.desc'),
        headers: _headers(_key(node)),
      )
          .timeout(const Duration(seconds: 8));
      sw.stop();
      if (r.statusCode != 200) {
        print('GET → Node $node | ${r.statusCode} | ${r.body}');
        return _Fetch(
          [],
          NodeTrace(
              node: node,
              ok: false,
              ms: sw.elapsedMilliseconds,
              rows: 0,
              note: 'HTTP ${r.statusCode}'),
        );
      }
      final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      return _Fetch(
        list,
        NodeTrace(
            node: node,
            ok: true,
            ms: sw.elapsedMilliseconds,
            rows: list.length,
            note: 'OK'),
      );
    } catch (e) {
      sw.stop();
      print('DB ERROR (Node $node): $e');
      return _Fetch(
        [],
        NodeTrace(
            node: node,
            ok: false,
            ms: sw.elapsedMilliseconds,
            rows: 0,
            note: 'সংযোগ ব্যর্থ'),
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final results = await Future.wait([
      _fetchExpenses('A'),
      _fetchExpenses('B'),
    ]);

    final all = <Map<String, dynamic>>[];
    final traces = <NodeTrace>[];
    for (final r in results) {
      all.addAll(r.rows);
      traces.add(r.trace);
    }

    all.sort((a, b) {
      final dateA = (a['date'] ?? '').toString();
      final dateB = (b['date'] ?? '').toString();
      return dateB.compareTo(dateA);
    });

    lastTrace.value = QueryTrace(
      label: 'SELECT * FROM EXPENSE ORDER BY date DESC',
      time: DateTime.now(),
      nodes: traces,
      mergedRows: all.length,
    );
    return all;
  }

  // ═══════════════════════════════════════════════
  // NODE STATUS — Dashboard এর জন্য
  // ═══════════════════════════════════════════════
  static Future<NodeStatus> checkNode(String node) async {
    if (isNodeDown(node)) {
      return NodeStatus(
          node: node, state: 'simulated', pingMs: 0, counts: const {});
    }

    // টেবিল → গোনার কলাম (settings-এ id নেই, key আছে)
    final Map<String, String> tables = node == 'C'
        ? {
      'users': 'id',
      'budgets': 'id',
      'settings': 'key',
      'expense_core': 'id',
    }
        : {'expenses': 'id'};

    final counts = <String, int>{};
    int ping = 0;
    try {
      int i = 0;
      for (final entry in tables.entries) {
        final sw = Stopwatch()..start();
        final r = await http
            .get(
          Uri.parse('${_url(node)}/rest/v1/${entry.key}?select=${entry.value}'),
          headers: _headers(_key(node)),
        )
            .timeout(const Duration(seconds: 8));
        sw.stop();
        if (i == 0) ping = sw.elapsedMilliseconds;
        if (r.statusCode != 200) {
          throw Exception('HTTP ${r.statusCode} (${entry.key})');
        }
        counts[entry.key] = (jsonDecode(r.body) as List).length;
        i++;
      }
      return NodeStatus(
          node: node, state: 'online', pingMs: ping, counts: counts);
    } catch (e) {
      print('NODE $node check failed: $e');
      return NodeStatus(
          node: node, state: 'offline', pingMs: 0, counts: counts);
    }
  }

  // ═══════════════════════════════════════════════
  // UPDATE EXPENSE (node-সচেতন)
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
    String? originalNodeId,
  }) async {
    final newNode = _getNodeForDate(date);
    final oldLetter = nodeLetter(originalNodeId);
    final oldNode = oldLetter.isNotEmpty ? oldLetter : newNode;

    if (isNodeDown(newNode) || isNodeDown(oldNode)) {
      final bad = isNodeDown(newNode) ? newNode : oldNode;
      throw NodeDownException(
          'Node $bad এখন বন্ধ (সিমুলেশন) — আপডেট করা যাচ্ছে না');
    }

    try {
      // তারিখ বদলে অন্য বছরে গেলে row এক node থেকে অন্য node-এ সরাতে হয়
      // (আগে নতুন node-এ লেখা, তারপর পুরনোটা মোছা — যাতে ডেটা হারিয়ে না যায়)
      if (oldNode != newNode) {
        final added = await addExpense(
          title: title,
          amount: amount,
          type: type,
          category: category,
          date: date,
          account: account,
          isRecurring: isRecurring,
        );
        if (!added) return false;
        return await deleteExpense(id, date,
            nodeId: 'node_${oldNode.toLowerCase()}');
      }

      final response = await http.patch(
        Uri.parse('${_url(newNode)}/rest/v1/expenses?id=eq.$id&user_id=eq.$_uid'),
        headers: _headers(_key(newNode)),
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
      final ok = response.statusCode == 200 || response.statusCode == 204;
      if (ok) await _updateCore(id, newNode, amount, category, date);
      return ok;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  /// Node C-র expense_core (vertical fragment) কপিও আপডেট রাখা
  static Future<void> _updateCore(
      int id, String node, double amount, String category, String date) async {
    if (isNodeDown('C')) {
      print('CORE update skipped → Node C বন্ধ (সিমুলেশন)');
      return;
    }
    try {
      final r = await http.patch(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/expense_core?expense_ref_id=eq.$id&node_source=eq.node_${node.toLowerCase()}'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'amount': amount,
          'category': category,
          'date': date,
        }),
      );
      print('CORE update → Node C | ${r.statusCode}');
    } catch (e) {
      print('DB ERROR (core update): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE EXPENSE (node-সচেতন)
  // ═══════════════════════════════════════════════
  static Future<bool> deleteExpense(int id, String date,
      {String? nodeId}) async {
    // row আসলে যে node-এ আছে সেটাই ধরা হয় (না থাকলে তারিখ দেখে অনুমান)
    final letter = nodeLetter(nodeId);
    final node = letter.isNotEmpty ? letter : _getNodeForDate(date);
    if (isNodeDown(node)) {
      throw NodeDownException(
          'Node $node এখন বন্ধ (সিমুলেশন) — ডিলিট করা যাচ্ছে না');
    }
    try {
      final response = await http.delete(
        Uri.parse('${_url(node)}/rest/v1/expenses?id=eq.$id&user_id=eq.$_uid'),
        headers: _headers(_key(node)),
      );
      final ok = response.statusCode == 200 || response.statusCode == 204;
      if (ok) await _deleteCore(id, node);
      return ok;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  /// Node C থেকে ওই expense-এর expense_core কপিও মোছা
  static Future<void> _deleteCore(int id, String node) async {
    if (isNodeDown('C')) {
      print('CORE delete skipped → Node C বন্ধ (সিমুলেশন)');
      return;
    }
    try {
      final r = await http.delete(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/expense_core?expense_ref_id=eq.$id&node_source=eq.node_${node.toLowerCase()}'),
        headers: _headers(AppConfig.nodeCKey),
      );
      print('CORE delete → Node C | ${r.statusCode}');
    } catch (e) {
      print('DB ERROR (core delete): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE ALL — Reset (Node A বা B)
  // ═══════════════════════════════════════════════
  static Future<void> deleteAllExpenses(String node) async {
    if (isNodeDown(node)) return;
    try {
      await http.delete(
        Uri.parse('${_url(node)}/rest/v1/expenses?user_id=eq.$_uid'),
        headers: _headers(_key(node)),
      );
      // Vertical fragment sync: ওই node-এর expense_core row-ও মুছে দাও
      if (!isNodeDown('C')) {
        await http.delete(
          Uri.parse(
              '${AppConfig.nodeCUrl}/rest/v1/expense_core?node_source=eq.node_${node.toLowerCase()}&user_id=eq.$_uid'),
          headers: _headers(AppConfig.nodeCKey),
        );
      }
    } catch (e) {
      print('DB ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // BUDGETS — Node C তে
  // ═══════════════════════════════════════════════
  static Future<bool> setBudget(
      String category, double limit, String month) async {
    if (isNodeDown('C')) return false;
    try {
      final response = await http.post(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/budgets?on_conflict=user_id,category,month'),
        headers: {
          ..._headers(AppConfig.nodeCKey),
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({
          'category': category,
          'limit_amount': limit,
          'month': month,
          'user_id': currentUserId ?? 1,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('DB ERROR: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBudgets(String month) async {
    if (isNodeDown('C')) return [];
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/budgets?month=eq.$month&user_id=eq.$_uid'),
        headers: _headers(AppConfig.nodeCKey),
      );
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // SETTINGS — Node C তে
  // ═══════════════════════════════════════════════
  static Future<String> getSetting(String key, String defaultValue) async {
    if (isNodeDown('C')) return defaultValue;
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
    if (isNodeDown('C')) return false;
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
  // ACCOUNT TRANSFER (সরল সংস্করণ)
  // দুইটা লেনদেন পরপর লেখা হয়। এটা এখনো সত্যিকারের 2PC নয়
  // (prepare / commit / abort ধাপ পরে যোগ হবে)।
  // ═══════════════════════════════════════════════
  static Future<bool> transferBetweenAccounts({
    required String fromAccount,
    required String toAccount,
    required double amount,
    required String date,
  }) async {
    try {
      final out = await addExpense(
        title: 'Transfer out → $toAccount',
        amount: amount,
        type: 'Expense',
        category: 'Transfer',
        date: date,
        account: fromAccount,
      );
      if (!out) return false;
      return await addExpense(
        title: 'Transfer in ← $fromAccount',
        amount: amount,
        type: 'Income',
        category: 'Transfer',
        date: date,
        account: toAccount,
      );
    } catch (e) {
      print('TRANSFER ERROR: $e');
      return false;
    }
  }
} // ← DistributedDB class শেষ
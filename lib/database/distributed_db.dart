import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

// ═══════════════════════════════════════════════════════════
// সাহায্যকারী ক্লাসসমূহ (ড্যাশবোর্ড, মনিটরিং ও কুয়েরি ট্রেসের জন্য)
// ═══════════════════════════════════════════════════════════

/// কোনো নোড বন্ধ থাকলে (সিমুলেশন বা নেটওয়ার্ক এরর) এই এক্সেপশন ছোঁড়া হয়
class NodeDownException implements Exception {
  final String message;
  NodeDownException(this.message);
  @override
  String toString() => message;
}

/// একটি নির্দিষ্ট কুয়েরিতে কোনো নির্দিষ্ট নোডের (Node A, B, C) রেসপন্স ট্রেস
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

/// একটি সম্পূর্ণ ডিস্ট্রিবিউটেড কুয়েরির সার্বিক রেসপন্স ট্রেস (সব নোড মিলিয়ে)
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

/// ড্যাশবোর্ডে প্রতিটি নোডের লাইভ স্ট্যাটাস (অনলাইন, অফলাইন, পিং সময়)
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
// মূল ডিস্ট্রিবিউটেড ডাটাবেজ ক্লাস (DistributedDB)
// ═══════════════════════════════════════════════════════════
class DistributedDB {
  // ─────────────────────────────────────────────
  // গ্লোবাল স্টেট ভেরিয়েবলসমূহ
  // ─────────────────────────────────────────────

  /// ডেমো এবং টেস্টিংয়ের জন্য কৃত্রিমভাবে বন্ধ রাখা নোডসমূহের লিস্ট
  static final ValueNotifier<Set<String>> simulatedDown =
  ValueNotifier<Set<String>>(<String>{});

  /// সর্বশেষ চালানো getExpenses() কুয়েরির ট্রেস হিস্ট্রি
  static final ValueNotifier<QueryTrace?> lastTrace =
  ValueNotifier<QueryTrace?>(null);

  /// বর্তমানে লগইন থাকা ইউজারের ইমেইল এবং আইডি
  static String? _currentEmail;
  static dynamic currentUserId;

  static String? get currentEmail => _currentEmail;

  /// ইউজার লগআউট করলে আইডি রিলিজ করা
  static set currentEmail(String? v) {
    _currentEmail = v;
    if (v == null) currentUserId = null;
  }

  /// কুয়েরি ফিল্টারের জন্য বর্তমান ইউজার আইডি
  static String get _uid => currentUserId?.toString() ?? '0';

  // বায়োমেট্রিক লগইনের জন্য শেষ সফল লগইন সেশন তথ্য
  static String? _lastLoginEmail;
  static dynamic _lastLoginUserId;

  /// বায়োমেট্রিক যাচাই সফল হলে পূর্বের সেশন সক্রিয় করার মেথড
  static bool restoreLastSession() {
    if (_lastLoginEmail == null || _lastLoginUserId == null) return false;
    currentUserId = _lastLoginUserId;
    currentEmail = _lastLoginEmail;
    return true;
  }

  /// নোড বন্ধ আছে কিনা চেক করা
  static bool isNodeDown(String node) => simulatedDown.value.contains(node);

  /// নোড সিমুলেটেড ডাউন বা অনলাইন করা
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
  // নোড এবং নেটওয়ার্ক কনফিগারেশন হেলপার মেথড
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

  /// নোডের সংকেত লেটার (যেমন: node_a -> A)
  static String nodeLetter(dynamic nodeId) {
    final s = (nodeId ?? '').toString().toLowerCase();
    if (s.endsWith('_a')) return 'A';
    if (s.endsWith('_b')) return 'B';
    if (s.endsWith('_c')) return 'C';
    return '';
  }

  /// নোড অনুযায়ী থিম কালার রিটার্ন
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
  // নীতি: চলতি বছর (>= 2026) -> Node A, আগের বছর (< 2026) -> Node B
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
  // PASSWORD HASHING (SHA-256)
  // ═══════════════════════════════════════════════
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ═══════════════════════════════════════════════
  // AUTHENTICATION — Node C তে (Global Users Table)
  // ═══════════════════════════════════════════════
  
  /// নতুন অ্যাকাউন্ট তৈরি করা এবং হ্যাশ করা পাসওয়ার্ড Node C-তে সেভ করা
  static Future<bool> signup(String email, String password) async {
    if (isNodeDown('C')) {
      debugPrint('SIGNUP skipped → Node C বন্ধ (সিমুলেশন)');
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/users'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password_hash': _hashPassword(password),
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  /// ইউজারের ইমেইল ও পাসওয়ার্ড হ্যাশ যাচাই করে Node C থেকে লগইন অনুমোদন করা
  static Future<bool> login(String email, String password) async {
    if (isNodeDown('C')) {
      debugPrint('LOGIN skipped → Node C বন্ধ (সিমুলেশন)');
      return false;
    }
    try {
      final candidates = <String>{email, email.toLowerCase()};
      for (final candidate in candidates) {
        final response = await http.get(
          Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/users'
                '?email=eq.${Uri.encodeQueryComponent(candidate)}'
                '&password_hash=eq.${_hashPassword(password)}'
                '&select=id',
          ),
          headers: _headers(AppConfig.nodeCKey),
        );
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          currentUserId = data[0]['id'];
          currentEmail = candidate;
          _lastLoginUserId = currentUserId;
          _lastLoginEmail = candidate;
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // ADD EXPENSE — Horizontal & Vertical Fragmentation
  // তারিখ অনুযায়ী Node A বা B তে খরচ যুক্ত করে এবং Node C তে core অংশ ব্যাকআপ রাখে
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

      // Vertical Fragment — Node C তে core fields কপি সেভ
      if (response.statusCode == 201) {
        final created = jsonDecode(response.body);
        final refId = created is List ? created[0]['id'] : created['id'];
        await _saveVerticalFragment(refId, amount, category, date, node);
      }

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // VERTICAL FRAGMENT — Node C তে Core Fields সেভ
  // ═══════════════════════════════════════════════
  static Future<void> _saveVerticalFragment(
      dynamic refId,
      double amount,
      String category,
      String date,
      String nodeSource,
      ) async {
    if (isNodeDown('C')) {
      debugPrint('CORE skipped → Node C বন্ধ (সিমুলেশন)');
      return;
    }
    try {
      await http.post(
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
    } catch (e) {
      debugPrint('DB ERROR (core): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // GET ALL EXPENSES — Reconstruction (Node A ∪ Node B)
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
      debugPrint('DB ERROR (Node $node): $e');
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

  /// Node A এবং Node B থেকে প্যারালাল-এ সকল লেনদেন সংগ্রহ ও মার্জ করার মেথড
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

    if (traces.every((t) => t.ok) && await processRecurring(all) > 0) {
      return getExpenses();
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
  // NODE STATUS CHECK — Dashboard এর জন্য
  // ═══════════════════════════════════════════════
  static Future<NodeStatus> checkNode(String node) async {
    if (isNodeDown(node)) {
      return NodeStatus(
          node: node, state: 'simulated', pingMs: 0, counts: const {});
    }

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
      debugPrint('NODE $node check failed: $e');
      return NodeStatus(
          node: node, state: 'offline', pingMs: 0, counts: counts);
    }
  }

  // ═══════════════════════════════════════════════
  // UPDATE EXPENSE — Node aware update
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
      // যদি তারিখ পরিবর্তনের মাধ্যমে এক নোড থেকে অন্য নোডে শিফট হয় (Node Migration)
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
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  /// Node C-র expense_core (vertical fragment) কপিও আপডেট করা
  static Future<void> _updateCore(
      int id, String node, double amount, String category, String date) async {
    if (isNodeDown('C')) return;
    try {
      await http.patch(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/expense_core?expense_ref_id=eq.$id&node_source=eq.node_${node.toLowerCase()}'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'amount': amount,
          'category': category,
          'date': date,
        }),
      );
    } catch (e) {
      debugPrint('DB ERROR (core update): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE EXPENSE
  // ═══════════════════════════════════════════════
  static Future<bool> deleteExpense(int id, String date,
      {String? nodeId}) async {
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
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  /// Node C থেকে ওই খরচের expense_core অংশ মোছা
  static Future<void> _deleteCore(int id, String node) async {
    if (isNodeDown('C')) return;
    try {
      await http.delete(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/expense_core?expense_ref_id=eq.$id&node_source=eq.node_${node.toLowerCase()}'),
        headers: _headers(AppConfig.nodeCKey),
      );
    } catch (e) {
      debugPrint('DB ERROR (core delete): $e');
    }
  }

  // ═══════════════════════════════════════════════
  // DELETE ALL — Data Reset
  // ═══════════════════════════════════════════════
  static Future<void> deleteAllExpenses(String node) async {
    if (isNodeDown(node)) return;
    try {
      await http.delete(
        Uri.parse('${_url(node)}/rest/v1/expenses?user_id=eq.$_uid'),
        headers: _headers(_key(node)),
      );
      if (!isNodeDown('C')) {
        await http.delete(
          Uri.parse(
              '${AppConfig.nodeCUrl}/rest/v1/expense_core?node_source=eq.node_${node.toLowerCase()}&user_id=eq.$_uid'),
          headers: _headers(AppConfig.nodeCKey),
        );
      }
    } catch (e) {
      debugPrint('DB ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // BUDGETS — Node C তে (Replicated Global Table)
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
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  static Future<bool> deleteBudget(String category, String month) async {
    if (isNodeDown('C')) return false;
    try {
      final r = await http.delete(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/budgets'
                '?user_id=eq.$_uid'
                '&category=eq.${Uri.encodeQueryComponent(category)}'
                '&month=eq.${Uri.encodeQueryComponent(month)}'),
        headers: _headers(AppConfig.nodeCKey),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (e) {
      debugPrint('DB ERROR: $e');
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
      debugPrint('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // SAVINGS GOALS — Node C তে
  // ═══════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getGoals() async {
    if (isNodeDown('C')) return [];
    try {
      final r = await http.get(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/goals?user_id=eq.$_uid&order=id.asc'),
        headers: _headers(AppConfig.nodeCKey),
      );
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return [];
    }
  }

  static Future<bool> addGoal(String title, double target) async {
    if (isNodeDown('C')) return false;
    try {
      final r = await http.post(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/goals'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({
          'user_id': _uid,
          'title': title,
          'target_amount': target,
          'saved_amount': 0,
        }),
      );
      return r.statusCode == 201;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  static Future<bool> updateGoalSaved(dynamic id, double newSaved) async {
    if (isNodeDown('C')) return false;
    try {
      final r = await http.patch(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/goals?id=eq.$id&user_id=eq.$_uid'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({'saved_amount': newSaved}),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  static Future<bool> deleteGoal(dynamic id) async {
    if (isNodeDown('C')) return false;
    try {
      final r = await http.delete(
        Uri.parse(
            '${AppConfig.nodeCUrl}/rest/v1/goals?id=eq.$id&user_id=eq.$_uid'),
        headers: _headers(AppConfig.nodeCKey),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return false;
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
      debugPrint('DB ERROR: $e');
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
      debugPrint('DB ERROR: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════
  // RECURRING TRANSACTIONS — স্বয়ংক্রিয় মাসিক লেনদেন প্রসেস
  // ═══════════════════════════════════════════════
  static dynamic _recurringDoneFor;

  static Future<int> processRecurring(
      List<Map<String, dynamic>> expenses) async {
    if (currentUserId == null) return 0;
    if (_recurringDoneFor == currentUserId) return 0;
    if (isNodeDown('A') || isNodeDown('B')) return 0;
    _recurringDoneFor = currentUserId;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      String keyOf(Map<String, dynamic> e) =>
          '${e['title']}|${(e['amount'] as num).toDouble()}|${e['type']}|${e['category']}|${e['account']}';

      final latest = <String, Map<String, dynamic>>{};
      final doneThisMonth = <String>{};

      for (final e in expenses) {
        if (e['is_recurring'] != true) continue;
        final d = (e['date'] ?? '').toString();
        if (DateTime.tryParse(d) == null || d.length < 7) continue;
        final k = keyOf(e);
        if (d.substring(0, 7).compareTo(monthPrefix) >= 0) {
          doneThisMonth.add(k);
          continue;
        }
        final cur = latest[k];
        if (cur == null || d.compareTo(cur['date'].toString()) > 0) {
          latest[k] = e;
        }
      }

      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      int added = 0;

      for (final entry in latest.entries) {
        if (doneThisMonth.contains(entry.key)) continue;
        final src = entry.value;
        final srcDay = DateTime.parse(src['date'].toString()).day;
        final day = srcDay > lastDay ? lastDay : srcDay;
        final due = DateTime(now.year, now.month, day);
        if (due.isAfter(today)) continue;

        final dateStr =
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
        try {
          final ok = await addExpense(
            title: (src['title'] ?? '').toString(),
            amount: (src['amount'] as num).toDouble(),
            type: (src['type'] ?? 'Expense').toString(),
            category: (src['category'] ?? 'Other').toString(),
            date: dateStr,
            account: (src['account'] ?? 'Cash').toString(),
            isRecurring: true,
          );
          if (ok) added++;
        } catch (e) {
          debugPrint('RECURRING add failed: $e');
        }
      }
      return added;
    } catch (e) {
      debugPrint('RECURRING ERROR: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════
  // CHANGE PASSWORD — Node C তে পাসওয়ার্ড হ্যাশ আপডেট
  // ═══════════════════════════════════════════════
  static Future<String?> changePassword(
      String oldPassword, String newPassword) async {
    if (currentUserId == null) return 'Please login again';
    if (isNodeDown('C')) return 'Node C is currently down';
    try {
      final check = await http.get(
        Uri.parse(
          '${AppConfig.nodeCUrl}/rest/v1/users'
              '?id=eq.$_uid'
              '&password_hash=eq.${_hashPassword(oldPassword)}'
              '&select=id',
        ),
        headers: _headers(AppConfig.nodeCKey),
      );
      final found = jsonDecode(check.body);
      if (found is! List || found.isEmpty) {
        return 'Current password is incorrect';
      }

      final r = await http.patch(
        Uri.parse('${AppConfig.nodeCUrl}/rest/v1/users?id=eq.$_uid'),
        headers: _headers(AppConfig.nodeCKey),
        body: jsonEncode({'password_hash': _hashPassword(newPassword)}),
      );
      final body = jsonDecode(r.body);
      if ((r.statusCode == 200 || r.statusCode == 204) &&
          (r.statusCode == 204 || (body is List && body.isNotEmpty))) {
        return null;
      }
      return 'Could not update password';
    } catch (e) {
      debugPrint('DB ERROR: $e');
      return 'Something went wrong';
    }
  }

  // ═══════════════════════════════════════════════
  // STATS CALCULATIONS
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
      debugPrint('DB ERROR: $e');
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

      if (dayTotals.isEmpty) return [];
      final out = <Map<String, dynamic>>[];
      for (int i = 0; i < days; i++) {
        final d = DateTime(cutoff.year, cutoff.month, cutoff.day + i);
        final k =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        out.add({'day': k, 'total': dayTotals[k] ?? 0.0});
      }
      return out;
    } catch (e) {
      debugPrint('DB ERROR: $e');
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
      debugPrint('DB ERROR: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // ACCOUNT TRANSFER — অ্যাকাউন্টের মধ্যে ফান্ড ট্রান্সফার
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
      debugPrint('TRANSFER ERROR: $e');
      return false;
    }
  }
}

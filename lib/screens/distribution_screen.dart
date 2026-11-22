
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/distributed_db.dart';

class DistributionScreen extends StatefulWidget {
  const DistributionScreen({super.key});

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  Map<String, NodeStatus> statuses = {};
  bool isLoading = true;

  static const Map<String, List<String>> _meta = {
    'A': ['Node A', 'চলতি বছরের expenses', 'Horizontal fragment'],
    'B': ['Node B', 'পুরনো বছরের expenses', 'Horizontal fragment'],
    'C': ['Node C', 'users, budgets, settings', 'Global tables + expense_core'],
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => isLoading = true);
    final list = await Future.wait([
      DistributedDB.checkNode('A'),
      DistributedDB.checkNode('B'),
      DistributedDB.checkNode('C'),
    ]);
    if (!mounted) return;
    setState(() {
      statuses = {for (final s in list) s.node: s};
      isLoading = false;
    });
  }

  Future<void> _runTestQuery() async {
    await DistributedDB.getExpenses();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Distribution Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2940), Color(0xFF16213E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel("Nodes"),
                const SizedBox(height: 4),
                const Text(
                  "অ্যাপ একটা Global Schema দেখে, কিন্তু ডেটা আসলে তিন জায়গায় আছে",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: DistributedDB.simulatedDown,
                  builder: (context, downSet, _) {
                    return Column(
                      children: ['A', 'B', 'C']
                          .map((n) => _nodeCard(n, downSet))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel("Expense Distribution"),
                const SizedBox(height: 14),
                _distributionChart(),
                const SizedBox(height: 28),
                _sectionLabel("Fragmentation Rules"),
                const SizedBox(height: 14),
                _rulesCard(),
                const SizedBox(height: 28),
                _sectionLabel("Last Query Trace"),
                const SizedBox(height: 14),
                _traceSection(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _runTestQuery,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text("Test query চালান"),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _nodeCard(String node, Set<String> downSet) {
    final meta = _meta[node]!;
    final color = DistributedDB.nodeColor(node);
    final status = statuses[node];
    final simulated = downSet.contains(node);

    String chipText;
    Color chipColor;
    if (simulated) {
      chipText = 'SIMULATED DOWN';
      chipColor = Colors.orangeAccent;
    } else if (status == null) {
      chipText = 'CHECKING…';
      chipColor = Colors.white54;
    } else if (status.state == 'online') {
      chipText = 'ONLINE · ${status.pingMs} ms';
      chipColor = Colors.greenAccent;
    } else {
      chipText = 'OFFLINE';
      chipColor = Colors.redAccent;
    }

    Widget countsArea;
    if (simulated) {
      countsArea = const Text("এই node এখন বন্ধ ধরা হচ্ছে — ডেটা পাওয়া যাচ্ছে না",
          style: TextStyle(color: Colors.orangeAccent, fontSize: 12));
    } else if (status == null) {
      countsArea = const Text("পরীক্ষা চলছে…",
          style: TextStyle(color: Colors.white38, fontSize: 12));
    } else if (status.state != 'online') {
      countsArea = const Text("Node-এর সাথে যোগাযোগ হয়নি",
          style: TextStyle(color: Colors.redAccent, fontSize: 12));
    } else {
      countsArea = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: status.counts.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text("${e.key} · ${e.value}",
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          );
        }).toList(),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Text(node,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(meta[1],
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    Text(meta[2],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(chipText,
                style: TextStyle(
                    color: chipColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          countsArea,
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              const Expanded(
                child: Text("Failure simulate করুন",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              Switch(
                value: simulated,
                activeThumbColor: Colors.orangeAccent,
                onChanged: (v) {
                  DistributedDB.setNodeDown(node, v);
                  _refresh();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(22)),
      child: Center(
          child: Text(msg, style: const TextStyle(color: Colors.white38))),
    );
  }

  Widget _distributionChart() {
    final a = statuses['A']?.counts['expenses'] ?? 0;
    final b = statuses['B']?.counts['expenses'] ?? 0;
    if (a + b == 0) {
      return _emptyBox("দেখানোর মতো expense নেই (বা node বন্ধ)");
    }

    final sections = <PieChartSectionData>[];
    if (a > 0) {
      sections.add(PieChartSectionData(
        value: a.toDouble(),
        color: DistributedDB.nodeColor('A'),
        title: '$a',
        radius: 46,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ));
    }
    if (b > 0) {
      sections.add(PieChartSectionData(
        value: b.toDouble(),
        color: DistributedDB.nodeColor('B'),
        title: '$b',
        radius: 46,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 34,
                  sections: sections,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legend('A', 'Node A', a),
                const SizedBox(height: 10),
                _legend('B', 'Node B', b),
                const SizedBox(height: 10),
                Text("মোট ${a + b} row",
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String node, String label, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: DistributedDB.nodeColor(node), shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text("$label · $count",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _ruleRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8E7CFF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(body,
                    style:
                    const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard() {
    final year = DateTime.now().year;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _ruleRow(Icons.view_agenda_rounded, "Horizontal fragmentation",
              "year(date) ≥ $year → Node A, নইলে Node B"),
          _ruleRow(Icons.view_column_rounded, "Vertical copy",
              "expense_core (id, amount, category, date) → Node C"),
          _ruleRow(Icons.merge_type_rounded, "Reconstruction",
              "EXPENSE = EXPENSE_A ∪ EXPENSE_B"),
          _ruleRow(Icons.storage_rounded, "Allocation",
              "USERS, BUDGETS, SETTINGS → Node C"),
        ],
      ),
    );
  }

  Widget _traceSection() {
    return ValueListenableBuilder<QueryTrace?>(
      valueListenable: DistributedDB.lastTrace,
      builder: (context, trace, _) {
        if (trace == null) {
          return _emptyBox("এখনো কোনো query চলেনি");
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trace.label,
                  style: const TextStyle(
                      color: Color(0xFF8E7CFF),
                      fontFamily: 'monospace',
                      fontSize: 12)),
              const SizedBox(height: 4),
              Text(DateFormat('HH:mm:ss').format(trace.time),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              ...trace.nodes.map(_traceRow),
              const Divider(color: Colors.white12, height: 22),
              Row(
                children: [
                  const Icon(Icons.merge_type_rounded,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Merge (UNION) → ${trace.mergedRows} row",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _traceRow(NodeTrace t) {
    final color = DistributedDB.nodeColor(t.node);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(t.node,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Icon(t.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: t.ok ? Colors.greenAccent : Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text("${t.rows} row · ${t.ms} ms",
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Text(t.note,
              style: TextStyle(
                  color: t.ok ? Colors.white38 : Colors.orangeAccent,
                  fontSize: 11)),
        ],
      ),
    );
  }
}

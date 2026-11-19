import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/work_record.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../theme.dart';

/// 统计页：今日/本月/累计收入、累计工时、按雇主/工种/月份汇总。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<Ledger> _ledgers = [];
  List<WorkRecord> _records = [];

  @override
  void initState() {
    super.initState();
    DataNotifier.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataNotifier.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    _ledgers = await DatabaseHelper.instance.getLedgers();
    _records = await DatabaseHelper.instance.getAllRecords();
    if (!mounted) return;
    setState(() {});
  }

  double _sum(Iterable<WorkRecord> rs) =>
      rs.fold(0.0, (s, r) => s + PayService.total(r));

  Map<String, double> _groupBy(String Function(WorkRecord) keyOf) {
    final map = <String, double>{};
    for (final r in _records) {
      final k = keyOf(r);
      map[k] = (map[k] ?? 0) + PayService.total(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final now = DateTime.now();
    final todayAmt = _sum(_records.where((r) =>
        r.startTime.year == now.year &&
        r.startTime.month == now.month &&
        r.startTime.day == now.day));
    final monthAmt = _sum(_records.where((r) =>
        r.startTime.year == now.year && r.startTime.month == now.month));
    final totalAmt = _sum(_records);
    // 三类计薪方式的工作量口径不同，不能相加：时薪看工时、日薪看天数、计件看件数
    final totals = PayService.totalsOf(_records);

    final byEmployer = <String, double>{};
    for (final r in _records) {
      String name = s.uncategorized;
      for (final l in _ledgers) {
        if (l.id == r.ledgerId) {
          name = l.name;
          break;
        }
      }
      byEmployer[name] = (byEmployer[name] ?? 0) + PayService.total(r);
    }
    final byJob = _groupBy((r) =>
        r.jobType.trim().isEmpty ? s.noJobType : r.jobType.trim());
    final byMonth = _groupBy((r) =>
        '${r.startTime.year}-${r.startTime.month.toString().padLeft(2, '0')}');

    return Scaffold(
      appBar: AppBar(title: Text(s.statsSummary)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(todayAmt, monthAmt, totalAmt, s),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.schedule, color: Tones.primary(context)),
                  title: Text(s.totalHours),
                  trailing: Text(s.duration(totals.hourlyMinutes),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (totals.dailyDays > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.today_outlined, color: Tones.primary(context)),
                    title: Text(s.totalDays),
                    trailing: Text(s.daysCount(totals.dailyDays),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
                if (totals.pieces > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.inventory_2_outlined,
                        color: Tones.primary(context)),
                    title: Text(s.totalPieces),
                    trailing: Text(s.piecesCount(totals.pieces),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(s.byEmployerStats),
          ..._rankList(byEmployer, s),
          const SizedBox(height: 20),
          _sectionTitle(s.byJobStats),
          ..._rankList(byJob, s),
          const SizedBox(height: 20),
          _sectionTitle(s.byMonthStats),
          ..._monthList(byMonth, s),
        ],
      ),
    );
  }

  Widget _heroCard(double today, double month, double total, L10n s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: heroGradient(context),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _heroStat(s.today, today)),
              Expanded(child: _heroStat(s.thisMonth, month)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.totalIncome,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text(PayService.money(total),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, double value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(PayService.money(value),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      );

  List<Widget> _rankList(Map<String, double> data, L10n s) {
    if (data.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.noData, style: const TextStyle(color: Colors.grey)),
        )
      ];
    }
    final max = data.values.reduce((a, b) => a > b ? a : b);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) {
      final double ratio = max > 0 ? e.value / max : 0.0;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(PayService.money(e.value),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Tones.primaryInk(context))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: Tones.primary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _monthList(Map<String, double> data, L10n s) {
    if (data.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.noData, style: const TextStyle(color: Colors.grey)),
        )
      ];
    }
    final keys = data.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      Card(
        child: Column(
          children: keys.map((k) {
            return ListTile(
              title: Text(s.yearMonthLabel(k)),
              trailing: Text(PayService.money(data[k]!),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Tones.primaryInk(context))),
            );
          }).toList(),
        ),
      )
    ];
  }
}

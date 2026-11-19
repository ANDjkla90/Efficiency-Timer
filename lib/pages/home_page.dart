import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/work_record.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../theme.dart';
import 'ledger_manage_page.dart';
import 'record_page.dart';

/// 首页 = 快速记账工作台。
/// 核心三件事：一眼看今日工资/累计收入、一步记一笔、随手翻最近记录。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Ledger> _ledgers = [];
  List<WorkRecord> _records = [];
  Ledger? _current;
  WorkRecord? _latest;

  double _todayAmount = 0;
  int _todayMinutes = 0;
  int _todayCount = 0;
  double _monthAmount = 0;
  double _totalAmount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    DataNotifier.instance.addListener(_load);
    AppSettings.instance.addListener(_load); // 语言切换后刷新相对时间等
    _load();
    _checkOnboarding();
  }

  @override
  void dispose() {
    DataNotifier.instance.removeListener(_load);
    AppSettings.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final ledgers = await DatabaseHelper.instance.getLedgers();
    final records = await DatabaseHelper.instance.getAllRecords();
    final latest = await DatabaseHelper.instance.getLatestRecord();

    final now = DateTime.now();
    double todayAmt = 0, monthAmt = 0, totalAmt = 0;
    int todayMin = 0, todayCnt = 0;
    for (final r in records) {
      final amt = PayService.total(r);
      totalAmt += amt;
      final sameDay = r.startTime.year == now.year &&
          r.startTime.month == now.month &&
          r.startTime.day == now.day;
      final sameMonth =
          r.startTime.year == now.year && r.startTime.month == now.month;
      if (sameDay) {
        todayAmt += amt;
        todayMin += r.durationMinutes + r.overtimeMinutes;
        todayCnt++;
      }
      if (sameMonth) monthAmt += amt;
    }

    Ledger? cur;
    for (final l in ledgers) {
      if (l.isCurrent == 1) {
        cur = l;
        break;
      }
    }
    cur ??= ledgers.isNotEmpty ? ledgers.first : null;

    if (!mounted) return;
    setState(() {
      _ledgers = ledgers;
      _records = records;
      _latest = latest;
      _current = cur;
      _todayAmount = todayAmt;
      _todayMinutes = todayMin;
      _todayCount = todayCnt;
      _monthAmount = monthAmt;
      _totalAmount = totalAmt;
      _loaded = true;
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('onboarding_done') != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  Future<void> _showOnboarding() async {
    if (!mounted) return;
    final s = AppScope.stringsOf(context);
    final primary = Tones.primary(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(s.onboardingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.onboardingDesc),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.edit_note, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(s.onboardingFeature)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.lock_outline, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(s.privacyLine)),
            ]),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.startWork),
          ),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        actions: [
          IconButton(
            tooltip: s.employerShort,
            icon: const Icon(Icons.folder_outlined),
            onPressed: _openLedgerManage,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSalaryHero(s),
            const SizedBox(height: 12),
            _buildQuickStats(s),
            const SizedBox(height: 20),
            _buildRecordButton(s),
            const SizedBox(height: 10),
            _buildShortcuts(s),
            const SizedBox(height: 24),
            _buildRecentHeader(s),
            const SizedBox(height: 8),
            ..._buildRecentList(s),
          ],
        ),
      ),
    );
  }

  /// 顶部大字：今日工资 + 今日工时
  Widget _buildSalaryHero(L10n s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: heroGradient(context),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.todayWage,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(PayService.money(_todayAmount),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
              _todayMinutes > 0
                  ? '${s.todayHours} ${s.duration(_todayMinutes)}'
                  : s.todayEntries(_todayCount),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQuickStats(L10n s) {
    return Row(
      children: [
        Expanded(
            child: _statCard(s.monthIncome, PayService.money(_monthAmount),
                Icons.calendar_month)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(s.totalIncome, PayService.money(_totalAmount),
                Icons.account_balance_wallet_outlined)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    final primary = Tones.primary(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Tones.primaryInk(context))),
          ],
        ),
      ),
    );
  }

  /// 核心操作：一步记一笔
  Widget _buildRecordButton(L10n s) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Tones.primary(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _startRecord,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Text(s.recordOne,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcuts(L10n s) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _latest == null ? null : _copyLast,
            icon: const Icon(Icons.content_copy, size: 18),
            label: Text(s.copyLast),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openLedgerManage,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: Text(_current == null ? s.addEmployer : s.switchEmployer),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentHeader(L10n s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(s.recentWork,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(s.allInRecords,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  List<Widget> _buildRecentList(L10n s) {
    if (_records.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.edit_note, size: 44, color: Colors.grey),
                const SizedBox(height: 10),
                Text(s.noRecords, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Text(s.noRecordsHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ),
      ];
    }
    return _records.take(8).map((r) => _recordTile(r, s)).toList();
  }

  Widget _recordTile(WorkRecord r, L10n s) {
    final employer = _employerName(r.ledgerId, s);
    final subtype = <String>[
      if (r.jobType.isNotEmpty) r.jobType,
      PayService.quantityText(r, s),
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Tones.onPrimarySoft(context),
          child: Text(
              employer.isNotEmpty ? employer.substring(0, 1) : '?',
              style: TextStyle(
                  color: Tones.primaryInk(context), fontWeight: FontWeight.bold)),
        ),
        // 时薪记录显示到分钟；日薪/计件没有具体上班时刻，只显示日期
        title: Text(r.payType == PayService.typeHourly
            ? s.dateShort(r.startTime)
            : s.dateFull(r.startTime)),
        subtitle: Text('$employer · $subtype',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Text(PayService.money(PayService.total(r)),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Tones.primaryInk(context))),
        onTap: () => _editRecord(r),
      ),
    );
  }

  String _employerName(int id, L10n s) {
    for (final l in _ledgers) {
      if (l.id == id) return l.name;
    }
    return s.employer;
  }

  void _startRecord() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPage(initialLedger: _current),
      ),
    ).then((_) => _load());
  }

  void _copyLast() {
    final last = _latest;
    if (last == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordPage(copyFrom: last)),
    ).then((_) => _load());
  }

  void _editRecord(WorkRecord r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordPage(editingRecord: r)),
    ).then((_) => _load());
  }

  void _openLedgerManage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LedgerManagePage()),
    ).then((_) => _load());
  }
}

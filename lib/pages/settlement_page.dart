import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/settlement.dart';
import '../models/work_record.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../services/settlement_service.dart';
import '../theme.dart';

/// 结算对账：选雇主 + 周期 → 汇总未结算记录 → 生成结算单。
/// 历史结算单可复制成纯文本账单发给雇主，也可撤销后重新结算。
class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  static const int _periodThisMonth = 0;
  static const int _periodLastMonth = 1;
  static const int _periodCustom = 2;

  List<Ledger> _ledgers = [];
  List<WorkRecord> _records = [];
  List<Settlement> _settlements = [];
  int? _ledgerId;
  int _period = _periodThisMonth;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    DataNotifier.instance.addListener(_load);
    AppSettings.instance.addListener(_load);
    _load();
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
    final settlements = await DatabaseHelper.instance.getSettlements();
    if (!mounted) return;
    setState(() {
      _ledgers = ledgers;
      _records = records;
      _settlements = settlements;
      _ledgerId ??= (ledgers.isNotEmpty ? ledgers.first.id : null);
      if (_ledgerId != null && !ledgers.any((l) => l.id == _ledgerId)) {
        _ledgerId = ledgers.isNotEmpty ? ledgers.first.id : null;
      }
    });
  }

  String _employerName(int id, L10n s) {
    for (final l in _ledgers) {
      if (l.id == id) return l.name;
    }
    return s.uncategorized;
  }

  (DateTime, DateTime) get _bounds {
    final now = DateTime.now();
    switch (_period) {
      case _periodLastMonth:
        return SettlementService.lastMonth(now);
      case _periodCustom:
        final c = _custom;
        if (c == null) return SettlementService.thisMonth(now);
        final from = DateTime(c.start.year, c.start.month, c.start.day);
        final to = DateTime(c.end.year, c.end.month, c.end.day)
            .add(const Duration(days: 1));
        return (from, to);
      default:
        return SettlementService.thisMonth(now);
    }
  }

  List<WorkRecord> get _pending {
    final id = _ledgerId;
    if (id == null) return const [];
    final (from, to) = _bounds;
    return SettlementService.unsettledInRange(
      _records,
      ledgerId: id,
      from: from,
      to: to,
    );
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom,
      helpText: AppScope.stringsOf(context).settlementPeriod,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _periodCustom;
    });
  }

  Future<void> _createSettlement(L10n s) async {
    final pending = _pending;
    if (pending.isEmpty) {
      _toast(s.settlementNonePending);
      return;
    }
    final amount = SettlementService.sum(pending);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.settlementCreateTitle),
        content: Text(s.settlementCreateDesc(
            pending.length, PayService.money(amount))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final (from, to) = _bounds;
    await DatabaseHelper.instance.createSettlement(
      settlement: Settlement(
        ledgerId: _ledgerId!,
        periodStart: from,
        periodEnd: to,
        amount: amount,
        recordCount: pending.length,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      recordIds: pending.map((r) => r.id!).toList(),
    );
    DataNotifier.instance.notify();
    await _load();
    if (!mounted) return;
    _toast(s.settlementCreated);
  }

  Future<void> _copyBill(Settlement st, L10n s) async {
    final records =
        await DatabaseHelper.instance.getRecordsBySettlement(st.id!);
    final text = SettlementService.buildBillText(
      employer: _employerName(st.ledgerId, s),
      from: st.periodStart,
      to: st.periodEnd,
      records: records,
      s: s,
      // 用结算单里的金额快照，不要重新求和
      totalOverride: st.amount,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _toast(s.settlementCopied);
  }

  Future<void> _revoke(Settlement st, L10n s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.settlementRevoke),
        content: Text(s.settlementRevokeDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.revertSettlement(st.id!);
    DataNotifier.instance.notify();
    await _load();
    if (!mounted) return;
    _toast(s.settlementRevoked);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final pending = _pending;
    final pendingAmount = SettlementService.sum(pending);
    final (from, to) = _bounds;
    final endInclusive = to.subtract(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(title: Text(s.settlements)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ledgers.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(s.settlementNoEmployer,
                    style: const TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            _buildPickerCard(s, from, endInclusive),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: Tones.primary(context)),
                        const SizedBox(width: 8),
                        Text(s.settlementPending,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text(PayService.money(pendingAmount),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Tones.primaryInk(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pending.isEmpty
                          ? s.settlementNonePending
                          : s.settlementPendingSummary(
                              pending.length, PayService.money(pendingAmount)),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            pending.isEmpty ? null : () => _createSettlement(s),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(s.settlementNew),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(s.settlementHistory,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_settlements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s.settlementEmpty,
                  style: const TextStyle(color: Colors.grey)),
            )
          else
            ..._settlements.map((st) => _buildHistory(st, s)),
        ],
      ),
    );
  }

  Widget _buildPickerCard(L10n s, DateTime from, DateTime endInclusive) {
    final items = <(int, String)>[
      (_periodThisMonth, s.settlementThisMonth),
      (_periodLastMonth, s.settlementLastMonth),
      (_periodCustom, s.settlementCustom),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.settlementPeriod,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _ledgerId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.employer,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: _ledgers
                  .map((l) => DropdownMenuItem<int>(
                        value: l.id,
                        child: Text(l.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _ledgerId = v),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: items.map((e) {
                return ChoiceChip(
                  label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                  selected: _period == e.$1,
                  onSelected: (_) {
                    if (e.$1 == _periodCustom) {
                      _pickCustom();
                    } else {
                      setState(() => _period = e.$1);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              s.rangeCustomSummary(
                  s.dateOnly(from), s.dateOnly(endInclusive)),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(Settlement st, L10n s) {
    final endInclusive = st.periodEnd.subtract(const Duration(days: 1));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_employerName(st.ledgerId, s)} · ${s.settlementSettledTag}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(PayService.money(st.amount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Tones.primaryInk(context))),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${s.dateOnly(st.periodStart)} - ${s.dateOnly(endInclusive)} · '
              '${s.settlementRecordCount(st.recordCount)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _copyBill(st, s),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: Text(s.settlementCopyBill),
                ),
                TextButton.icon(
                  onPressed: () => _revoke(st, s),
                  icon: const Icon(Icons.undo, size: 16),
                  label: Text(s.settlementRevoke),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

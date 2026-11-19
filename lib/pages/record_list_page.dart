import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/work_record.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../theme.dart';
import 'record_page.dart';
import 'settlement_page.dart';

/// 账目页：按 日期 / 雇主 / 工种 三个维度查看账目、分组小计，支持时间段筛选。
/// 删除：左滑（可撤销）+ 长按菜单（二次确认），两种都能被发现。
class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key});

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  static const int _rangeAll = 0;
  static const int _rangeToday = 1;
  static const int _rangeWeek = 2;
  static const int _rangeMonth = 3;
  static const int _rangeCustom = 4;

  // 0=按日期 1=按雇主 2=按工种
  int _viewBy = 0;
  int _range = _rangeAll;
  DateTimeRange? _customRange;
  List<Ledger> _ledgers = [];
  List<WorkRecord> _all = [];
  String? _selectedJob; // 工种筛选（null=全部）
  String? _selectedEmployerKey; // 雇主筛选（null=全部）

  @override
  void initState() {
    super.initState();
    DataNotifier.instance.addListener(_load);
    AppSettings.instance.addListener(_load); // 语言切换后重新分组
    _load();
  }

  @override
  void dispose() {
    DataNotifier.instance.removeListener(_load);
    AppSettings.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    _ledgers = await DatabaseHelper.instance.getLedgers();
    _all = await DatabaseHelper.instance.getAllRecords();
    if (!mounted) return;
    setState(() {});
  }

  String _employerName(int id, L10n s) {
    for (final l in _ledgers) {
      if (l.id == id) return l.name;
    }
    return s.uncategorized;
  }

  List<String> get _allJobs {
    final set = <String>{};
    for (final r in _all) {
      if (r.jobType.trim().isNotEmpty) set.add(r.jobType.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 时间段边界 [from, to)；全部时返回 null
  (DateTime, DateTime)? get _rangeBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _rangeToday:
        return (today, today.add(const Duration(days: 1)));
      case _rangeWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (monday, monday.add(const Duration(days: 7)));
      case _rangeMonth:
        return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
      case _rangeCustom:
        final c = _customRange;
        if (c == null) return null;
        final from = DateTime(c.start.year, c.start.month, c.start.day);
        final to = DateTime(c.end.year, c.end.month, c.end.day)
            .add(const Duration(days: 1));
        return (from, to);
      default:
        return null;
    }
  }

  /// 当前筛选后的记录（按 start_time 倒序）
  List<WorkRecord> get _filtered {
    var list = _all;
    final bounds = _rangeBounds;
    if (bounds != null) {
      final (from, to) = bounds;
      list = list
          .where((r) =>
              !r.startTime.isBefore(from) && r.startTime.isBefore(to))
          .toList();
    }
    if (_viewBy == 2 && _selectedJob != null) {
      list = list.where((r) => r.jobType.trim() == _selectedJob).toList();
    }
    if (_viewBy == 1 && _selectedEmployerKey != null) {
      list = list
          .where((r) => r.ledgerId.toString() == _selectedEmployerKey)
          .toList();
    }
    return list;
  }

  /// 按当前维度分组：[ (分组名, 记录列表, 小计) ]
  List<(String, List<WorkRecord>, double)> get _groups {
    final s = AppSettings.instance.strings;
    final map = <String, List<WorkRecord>>{};
    for (final r in _filtered) {
      String key;
      switch (_viewBy) {
        case 1:
          key = _employerName(r.ledgerId, s);
          break;
        case 2:
          key = r.jobType.trim().isEmpty ? s.noJobType : r.jobType.trim();
          break;
        default:
          key = s.dateGroupKey(r.startTime);
      }
      (map[key] ??= []).add(r);
    }
    final keys = map.keys.toList();
    // 按日期维度：最新日期在前；其余按金额降序
    if (_viewBy == 0) {
      keys.sort((a, b) => b.compareTo(a));
    } else {
      keys.sort((a, b) {
        final amtA = map[a]!.fold(0.0, (sum, r) => sum + PayService.total(r));
        final amtB = map[b]!.fold(0.0, (sum, r) => sum + PayService.total(r));
        return amtB.compareTo(amtA);
      });
    }
    return keys.map((k) {
      final list = map[k]!;
      final sum = list.fold(0.0, (acc, r) => acc + PayService.total(r));
      return (k, list, sum);
    }).toList();
  }

  /// 删除后弹「撤销」：5 秒内可把这一笔原样写回（新的 id，内容不变）。
  Future<void> _deleteWithUndo(WorkRecord r, L10n s) async {
    setState(() => _all.removeWhere((e) => e.id == r.id));
    await DatabaseHelper.instance.deleteRecord(r.id!);
    DataNotifier.instance.notify();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.deletedOne),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            await DatabaseHelper.instance.insertRecord(r.copyWithoutId());
            DataNotifier.instance.notify();
            await _load();
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.restoredOne)));
          },
        ),
      ),
    );
    _load();
  }

  /// 删除确认。只有「已结算」的记录才需要额外提醒：
  /// 历史结算单金额是快照，删记录不会改它。
  Future<bool> _confirmDelete(WorkRecord r, L10n s) async {
    final desc = s.deleteRecordDesc(PayService.money(PayService.total(r)));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteRecordTitle),
        content: Text(r.settlementId == null
            ? desc
            : '$desc\n\n${s.deleteSettledDesc}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 长按菜单：编辑 / 删除（删除仍需二次确认）
  Future<void> _showActions(WorkRecord r, L10n s) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(s.editRecord),
              onTap: () {
                Navigator.pop(ctx);
                _edit(r);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(s.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await _confirmDelete(r, s);
                if (ok) {
                  // 长按路径已经确认过，直接删，不再弹撤销（避免双重确认后还能撤回）
                  setState(() => _all.removeWhere((e) => e.id == r.id));
                  await DatabaseHelper.instance.deleteRecord(r.id!);
                  DataNotifier.instance.notify();
                  await _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(WorkRecord r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordPage(editingRecord: r)),
    );
    _load();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customRange,
      helpText: AppScope.stringsOf(context).filterRange,
    );
    if (picked == null) {
      if (_customRange == null) {
        setState(() => _range = _rangeAll);
      }
      return;
    }
    setState(() {
      _customRange = picked;
      _range = _rangeCustom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final groups = _groups;
    final grandTotal =
        _filtered.fold(0.0, (sum, r) => sum + PayService.total(r));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.records),
        actions: [
          IconButton(
            tooltip: s.settlements,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettlementPage()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${s.totalPrefix} ${PayService.money(grandTotal)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Tones.primaryInk(context))),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildViewSwitch(s),
          _buildRangeBar(s),
          if (_viewBy == 1) _buildEmployerFilter(s),
          if (_viewBy == 2) _buildJobFilter(s),
          Expanded(
            child: _all.isEmpty
                ? Center(
                    child: Text(s.noRecordsHintRecords,
                        style: const TextStyle(color: Colors.grey)))
                : groups.isEmpty
                    ? Center(
                        child: Text(s.noFiltered,
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final g = groups[i];
                          return _buildGroup(g.$1, g.$2, g.$3, s);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitch(L10n s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text(s.byDate), icon: const Icon(Icons.calendar_today)),
          ButtonSegment(value: 1, label: Text(s.byEmployer), icon: const Icon(Icons.person_outline)),
          ButtonSegment(value: 2, label: Text(s.byJob), icon: const Icon(Icons.work_outline)),
        ],
        selected: {_viewBy},
        onSelectionChanged: (set) {
          setState(() {
            _viewBy = set.first;
            _selectedJob = null;
            _selectedEmployerKey = null;
          });
        },
      ),
    );
  }

  /// 时间段筛选：全部 / 今日 / 本周 / 本月 / 自定义
  Widget _buildRangeBar(L10n s) {
    final items = <(int, String)>[
      (_rangeAll, s.rangeAll),
      (_rangeToday, s.rangeToday),
      (_rangeWeek, s.rangeWeek),
      (_rangeMonth, s.rangeMonth),
      (_rangeCustom, s.rangeCustom),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: items.map((e) {
              final selected = _range == e.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) {
                    if (e.$1 == _rangeCustom) {
                      _pickCustomRange();
                    } else {
                      setState(() => _range = e.$1);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (_range == _rangeCustom && _customRange != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              s.rangeCustomSummary(
                s.dateFull(_customRange!.start),
                s.dateFull(_customRange!.end),
              ),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.swipe_left, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(s.swipeHint,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployerFilter(L10n s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: DropdownButtonFormField<String?>(
          initialValue: _selectedEmployerKey,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: s.filterEmployer,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(s.allEmployers)),
            ..._ledgers.map((l) => DropdownMenuItem<String?>(
                  value: l.id.toString(),
                  child: Text(l.name),
                )),
          ],
          onChanged: (v) => setState(() => _selectedEmployerKey = v),
        ),
      ),
    );
  }

  Widget _buildJobFilter(L10n s) {
    final jobs = _allJobs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: DropdownButtonFormField<String?>(
          initialValue: _selectedJob,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: s.filterJob,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(s.allJobs)),
            ...jobs.map((j) => DropdownMenuItem<String?>(value: j, child: Text(j))),
          ],
          onChanged: (v) => setState(() => _selectedJob = v),
        ),
      ),
    );
  }

  Widget _buildGroup(String title, List<WorkRecord> list, double sum, L10n s) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Tones.onPrimarySoft(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${s.subtotal} ${PayService.money(sum)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Tones.primaryInk(context),
                        fontSize: 14)),
              ],
            ),
          ),
          ...list.map((r) => _buildItem(r, s)),
        ],
      ),
    );
  }

  Widget _buildItem(WorkRecord r, L10n s) {
    final employer = _employerName(r.ledgerId, s);
    final isHourly = r.payType == PayService.typeHourly;
    final bits = <String>[
      employer,
      if (r.jobType.isNotEmpty) r.jobType,
      PayService.quantityText(r, s),
      if (isHourly && r.breakMinutes > 0)
        '${s.breakMark} ${s.duration(r.breakMinutes)}',
      if (isHourly && r.overtimeMinutes > 0)
        '${s.overtimeMark}${s.duration(r.overtimeMinutes)}',
      if (r.subsidy > 0)
        '${s.subsidyMark}${AppSettings.instance.currency.format(r.subsidy)}',
    ];
    // 时薪按时钟显示开始时间；日薪/计件没有「几点上班」的概念，显示计薪方式
    final head = isHourly
        ? TimeOfDay.fromDateTime(r.startTime).format(context)
        : (r.payType == PayService.typeDaily ? s.daily : s.piece);
    return Dismissible(
      key: ValueKey('record-${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // 已结算的记录删除前提醒；未结算的直接删，靠 SnackBar 撤销兜底
      confirmDismiss: (_) async =>
          r.settlementId == null ? true : await _confirmDelete(r, s),
      onDismissed: (_) => _deleteWithUndo(r, s),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                  '$head  ·  ${PayService.money(PayService.total(r))}',
                  style: const TextStyle(fontSize: 14)),
            ),
            if (r.settlementId != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Tones.onPrimarySoft(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(s.settledTag,
                    style: TextStyle(
                        fontSize: 10,
                        color: Tones.primaryInk(context),
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(bits.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
          onPressed: () => _edit(r),
        ),
        onLongPress: () => _showActions(r, s),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/work_record.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import 'ledger_manage_page.dart';

/// 记一笔：快速记录一次/一天的工作。
/// 按账本的计薪方式切换录入内容：
///   时薪 → 日期 + 起止时间/工时 + 时薪（+ 加班 + 补贴）
///   日薪 → 日期 + 天数 + 日薪（+ 补贴）
///   计件 → 日期 + 件数 + 件单价（+ 补贴）
/// 三种入口：新增、编辑（editingRecord）、复制上次（copyFrom）。
class RecordPage extends StatefulWidget {
  final Ledger? initialLedger;
  final WorkRecord? editingRecord;
  final WorkRecord? copyFrom;

  const RecordPage({
    super.key,
    this.initialLedger,
    this.editingRecord,
    this.copyFrom,
  });

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  Ledger? _ledger;
  List<Ledger> _ledgers = [];

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _rateCtrl = TextEditingController();
  final _manualHoursCtrl = TextEditingController(); // 直接填工时（小时）
  final _breakCtrl = TextEditingController(text: '0'); // 休息扣除（分钟）
  final _daysCtrl = TextEditingController(text: '1'); // 日薪：天数
  final _piecesCtrl = TextEditingController(); // 计件：件数
  final _overtimeCtrl = TextEditingController(); // 加班小时数（文本）
  final _overtimeRateCtrl = TextEditingController(); // 加班时薪
  final _subsidyCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loaded = false;
  bool _useEndTime = true; // true=按起止时间；false=直接填工时
  int? _payTypeOverride; // 编辑旧记录时沿用记录里的计薪方式快照

  /// 当前生效的计薪方式：编辑旧记录优先用快照，否则用所选账本的设置
  int get _payType =>
      _payTypeOverride ?? _ledger?.payType ?? PayService.typeHourly;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _ledgers = await DatabaseHelper.instance.getLedgers();
    final source = widget.editingRecord ?? widget.copyFrom;
    final now = DateTime.now();

    // 默认时间：今天 09:00 - 18:00
    _date = DateTime(now.year, now.month, now.day);
    _start = const TimeOfDay(hour: 9, minute: 0);
    _end = const TimeOfDay(hour: 18, minute: 0);

    if (source != null) {
      _date = DateTime(
          source.startTime.year, source.startTime.month, source.startTime.day);
      _start = TimeOfDay.fromDateTime(source.startTime);
      _end = TimeOfDay.fromDateTime(source.endTime);
      _rateCtrl.text = source.rate > 0 ? _num(source.rate) : '';
      _manualHoursCtrl.text = source.durationMinutes > 0
          ? _num(source.durationMinutes / 60.0)
          : '';
      _breakCtrl.text = '${source.breakMinutes}';
      _overtimeCtrl.text = source.overtimeMinutes > 0
          ? _num(source.overtimeMinutes / 60.0)
          : '';
      _overtimeRateCtrl.text =
          source.overtimeRate > 0 ? _num(source.overtimeRate) : '';
      _subsidyCtrl.text = source.subsidy > 0 ? _num(source.subsidy) : '';
      _jobCtrl.text = source.jobType;
      _noteCtrl.text = source.note;
      if (source.pieceCount > 0) {
        _piecesCtrl.text = '${source.pieceCount}';
      }
      if (source.payType == PayService.typeDaily) {
        _daysCtrl.text =
            '${source.pieceCount > 0 ? source.pieceCount : 1}';
      }
      // 起止时间与工时对不上，说明这笔是按「填工时」记的，编辑时沿用该记法。
      // 有休息扣除时，时钟跨度 = 计薪工时 + 休息，仍属于「起止时间」记法。
      final clockMinutes = minutesBetweenClocks(
        minuteOfDay(source.startTime),
        minuteOfDay(source.endTime),
      );
      _useEndTime = clockMinutes ==
          source.durationMinutes + (source.breakMinutes > 0 ? source.breakMinutes : 0);
      // 复制上次时，日期回到今天（便于连续记工）
      if (widget.copyFrom != null) {
        _date = DateTime(now.year, now.month, now.day);
      }
      for (final l in _ledgers) {
        if (l.id == source.ledgerId) {
          _ledger = l;
          break;
        }
      }
    }

    _payTypeOverride = widget.editingRecord?.payType;
    _ledger ??= widget.initialLedger;
    _ledger ??= _ledgers.isEmpty
        ? null
        : (_ledgers.firstWhere((l) => l.isCurrent == 1,
            orElse: () => _ledgers.first));

    // 单价默认带出所选账本对应计薪方式的单价
    if (_rateCtrl.text.isEmpty && _ledger != null) {
      _rateCtrl.text = _num(_rateOf(_ledger!));
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  /// 账本在自身计薪方式下的单价
  double _rateOf(Ledger l) {
    switch (l.payType) {
      case PayService.typeDaily:
        return l.dailyRate;
      case PayService.typePiece:
        return l.pieceRate;
      default:
        return l.hourlyRate;
    }
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _manualHoursCtrl.dispose();
    _breakCtrl.dispose();
    _daysCtrl.dispose();
    _piecesCtrl.dispose();
    _overtimeCtrl.dispose();
    _overtimeRateCtrl.dispose();
    _subsidyCtrl.dispose();
    _jobCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ============ 计算 ============
  int get _startMinutes => clockMinutes(_start.hour, _start.minute);
  int get _endMinutes => clockMinutes(_end.hour, _end.minute);

  /// 起止时间之间的钟点跨度（未扣休息）。跨 0 点按次日算：22:00 → 06:00 = 480。
  int get _clockSpan => minutesBetweenClocks(_startMinutes, _endMinutes);

  /// 休息扣除（分钟）：只允许非负整数
  int get _breakMinutes {
    final v = int.tryParse(_breakCtrl.text.trim()) ?? 0;
    return v < 0 ? 0 : v;
  }

  /// 本次计薪工时（分钟）= 钟点跨度 - 休息扣除；手填工时模式下直接用填的数。
  int get _minutes {
    if (!_useEndTime) {
      final h = double.tryParse(_manualHoursCtrl.text.trim()) ?? 0;
      return (h * 60).round();
    }
    return paidMinutes(_clockSpan, _breakMinutes);
  }

  /// 日薪天数：至少 1 天
  int get _days {
    final v = double.tryParse(_daysCtrl.text.trim()) ?? 1;
    final n = v.round();
    return n < 1 ? 1 : n;
  }

  /// 计件件数：至少 0
  int get _pieces {
    final v = double.tryParse(_piecesCtrl.text.trim()) ?? 0;
    return v < 0 ? 0 : v.round();
  }

  int get _overtimeMinutes {
    final h = double.tryParse(_overtimeCtrl.text.trim()) ?? 0;
    return (h * 60).round();
  }

  double get _rate => double.tryParse(_rateCtrl.text.trim()) ?? 0;
  double get _overtimeRate =>
      double.tryParse(_overtimeRateCtrl.text.trim()) ?? 0;
  double get _subsidy => double.tryParse(_subsidyCtrl.text.trim()) ?? 0;

  /// 正常工资：与 PayService.baseWage 同一口径
  double get _base {
    switch (_payType) {
      case PayService.typeDaily:
        return _rate * _days;
      case PayService.typePiece:
        return _rate * _pieces;
      default:
        return _rate * _minutes / 60.0;
    }
  }

  double get _overtimePay => _payType == PayService.typeHourly &&
          _overtimeMinutes > 0 &&
          _overtimeRate > 0
      ? _overtimeRate * _overtimeMinutes / 60.0
      : 0;

  double get _total => _base + _overtimePay + _subsidy;

  // ============ 保存 ============
  Future<void> _save(L10n s) async {
    final l = _ledger;
    if (l == null) {
      _toast(s.toastSelectEmployer);
      return;
    }
    if (_rate <= 0) {
      _toast(s.toastRate);
      return;
    }
    final payType = _payType;
    if (payType == PayService.typeHourly &&
        _useEndTime &&
        _breakMinutes > 0 &&
        _breakMinutes >= _clockSpan) {
      _toast(s.toastBreakTooLong(_clockSpan));
      return;
    }
    if (payType == PayService.typeHourly && _minutes <= 0) {
      _toast(_useEndTime ? s.toastTimeOrder : s.toastHours);
      return;
    }
    if (payType == PayService.typePiece && _pieces <= 0) {
      _toast(s.toastPieces);
      return;
    }

    final int durationMinutes;
    final int pieceCount;
    final DateTime startTime;
    final DateTime endTime;
    switch (payType) {
      case PayService.typeDaily:
        durationMinutes = 0;
        pieceCount = _days;
        // 日薪没有「几点上班」的概念，日期就是全部信息：存当天 00:00，
        // 避免给后续日历/时间线留下一个假的 09:00。
        startTime = startOfDayClock(_date, 0);
        endTime = startTime;
        break;
      case PayService.typePiece:
        durationMinutes = 0;
        pieceCount = _pieces;
        startTime = startOfDayClock(_date, 0);
        endTime = startTime;
        break;
      default:
        durationMinutes = _minutes;
        pieceCount = 0;
        // 起止时间模式：跨天时结束时刻落到次日
        // 填工时模式：结束时刻 = 开始 + 工时，两者永远一致
        final range = _useEndTime
            ? rangeFromClock(_date, _startMinutes, _endMinutes)
            : rangeFromDuration(_date, _startMinutes, _minutes);
        startTime = range.start;
        endTime = range.end;
    }

    final record = WorkRecord(
      id: widget.editingRecord?.id,
      ledgerId: l.id!,
      payType: payType,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      pieceCount: pieceCount,
      rate: _rate,
      overtimeMinutes:
          payType == PayService.typeHourly ? _overtimeMinutes : 0,
      overtimeRate: payType == PayService.typeHourly ? _overtimeRate : 0,
      subsidy: _subsidy,
      jobType: _jobCtrl.text.trim(),
      amount: _total,
      note: _noteCtrl.text.trim(),
      // 手填工时模式没有「休息」这回事，记 0 便于下次编辑还原
      breakMinutes:
          payType == PayService.typeHourly && _useEndTime ? _breakMinutes : 0,
      settlementId: widget.editingRecord?.settlementId,
      createdAt: widget.editingRecord?.createdAt ?? DateTime.now(),
    );

    if (widget.editingRecord == null) {
      await DatabaseHelper.instance.insertRecord(record);
    } else {
      await DatabaseHelper.instance.updateRecord(record);
    }
    DataNotifier.instance.notify();
    if (mounted) Navigator.pop(context, true);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============ 选择弹层 ============
  Future<void> _pickLedger(L10n s) async {
    if (_ledgers.isEmpty) {
      // 没有雇主，直接去创建
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LedgerManagePage()),
      );
      _ledgers = await DatabaseHelper.instance.getLedgers();
      if (_ledgers.isNotEmpty && mounted) {
        setState(() {
          _ledger = _ledgers.first;
          _payTypeOverride = null;
          _rateCtrl.text = _num(_rateOf(_ledgers.first));
        });
      }
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<Ledger>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(s.selectEmployerSheet,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._ledgesheets(s),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _ledger = picked;
        _payTypeOverride = null; // 换了雇主，计薪方式跟随新账本
        final rate = _rateOf(picked);
        if (rate > 0) _rateCtrl.text = _num(rate);
      });
    }
  }

  List<Widget> _ledgesheets(L10n s) => _ledgers.map((l) {
        final c = AppSettings.instance.currency;
        final unit = l.payType == PayService.typeDaily
            ? s.perDay
            : (l.payType == PayService.typePiece ? s.perPiece : s.perHour);
        return ListTile(
          leading: Icon(Icons.person_outline, color: Tones.primary(context)),
          title: Text(l.name),
          subtitle: Text('${c.format(_rateOf(l))}$unit'),
          trailing: _ledger?.id == l.id
              ? Icon(Icons.check, color: Tones.primary(context))
              : null,
          onTap: () => Navigator.pop(context, l),
        );
      }).toList();

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  // ============ 界面 ============
  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final isEdit = widget.editingRecord != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? s.editRecord
            : (widget.copyFrom != null ? s.copyLast : s.newRecord)),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _employerCard(s),
                const SizedBox(height: 12),
                _workCard(s),
                const SizedBox(height: 12),
                _moneyCard(s),
                const SizedBox(height: 12),
                _jobCard(s),
                const SizedBox(height: 20),
                _totalBar(s),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _save(s),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 17)),
                  child: Text(isEdit ? s.saveChanges : s.saveEntry),
                ),
              ],
            ),
    );
  }

  Widget _employerCard(L10n s) {
    final l = _ledger;
    final c = AppSettings.instance.currency;
    final unit = _payType == PayService.typeDaily
        ? s.perDay
        : (_payType == PayService.typePiece ? s.perPiece : s.perHour);
    // 单价以输入框为准：编辑旧记录时，账本可能已经涨价，
    // 卡片再显示「账本最新价」就会和输入框里的快照打架。
    final rate = _rate > 0 ? _rate : (l == null ? null : _rateOf(l));
    final tag = widget.editingRecord != null ? ' · ${s.rateSnapshotTag}' : '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Tones.onPrimarySoft(context),
          child: Icon(Icons.person_outline, color: Tones.primary(context)),
        ),
        title: Text(l?.name ?? s.selectEmployerSheet,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            rate == null
                ? s.tapNewOrSelect
                : '${_payTypeName(s)} ${c.format(rate)}$unit$tag'),
        trailing: const Icon(Icons.unfold_more),
        onTap: () => _pickLedger(s),
      ),
    );
  }

  String _payTypeName(L10n s) {
    switch (_payType) {
      case PayService.typeDaily:
        return s.daily;
      case PayService.typePiece:
        return s.piece;
      default:
        return s.hourly;
    }
  }

  Widget _workCard(L10n s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.workTime,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _tapRow(Icons.calendar_today, s.workDate, s.dateFull(_date), _pickDate),
            const Divider(height: 1),
            if (_payType == PayService.typeHourly) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(s.timeMethod, style: const TextStyle(fontSize: 15)),
                  const Spacer(),
                  SizedBox(
                    width: 190,
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(s.byTimeRange)),
                        ButtonSegment(value: false, label: Text(s.byManualHours)),
                      ],
                      selected: {_useEndTime},
                      onSelectionChanged: (set) =>
                          setState(() => _useEndTime = set.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_useEndTime) ...[
                _tapRow(Icons.login, s.startTime, _start.format(context), _pickStart),
                const Divider(height: 1),
                _tapRow(Icons.logout, s.endTime, _end.format(context), _pickEnd),
                const Divider(height: 1),
                _breakField(s),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _numberField(
                    controller: _manualHoursCtrl,
                    label: s.manualHoursLabel,
                    icon: Icons.schedule,
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(s.thisShift,
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const Spacer(),
                    Text(s.duration(_minutes),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (_useEndTime && _breakMinutes > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(s.breakDeducted(s.duration(_breakMinutes)),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ),
                    if (_useEndTime && crossesMidnight(_startMinutes, _endMinutes))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.nightlight_round,
                            size: 16, color: Tones.primary(context)),
                      ),
                  ],
                ),
              ),
            ],
            if (_payType == PayService.typeDaily) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _numberField(
                  controller: _daysCtrl,
                  label: s.daysLabel,
                  icon: Icons.today_outlined,
                  decimal: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.dailyHint,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
            if (_payType == PayService.typePiece) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _numberField(
                  controller: _piecesCtrl,
                  label: s.piecesLabel,
                  icon: Icons.inventory_2_outlined,
                  decimal: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.pieceHint,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 休息扣除：常用 0/30/60/90 分钟一键选，也能手填任意分钟数。
  Widget _breakField(L10n s) {
    const presets = <int>[0, 30, 60, 90];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.free_breakfast_outlined,
                  size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _breakCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.breakLabel,
                    suffixText: s.minuteUnit,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: presets.map((m) {
              return ChoiceChip(
                // 紧凑一点，让 4 个常用档位排在一行里
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                label: Text(
                  m == 0 ? s.breakNone : s.minutesShort(m),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: _breakMinutes == m,
                onSelected: (_) => setState(() => _breakCtrl.text = '$m'),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(s.breakHint,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _moneyCard(L10n s) {    final rateLabel = _payType == PayService.typeDaily
        ? s.dailyLabel
        : (_payType == PayService.typePiece ? s.pieceLabel : s.hourlyWage);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.wage,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _moneyField(
                controller: _rateCtrl,
                label: rateLabel,
                icon: Icons.payments_outlined,
                onChanged: (_) => setState(() {})),
            if (_payType == PayService.typeHourly) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _moneyField(
                        controller: _overtimeCtrl,
                        label: s.overtimeHours,
                        icon: Icons.more_time,
                        onChanged: (_) => setState(() {})),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _moneyField(
                        controller: _overtimeRateCtrl,
                        label: s.overtimeRate,
                        icon: Icons.local_fire_department_outlined,
                        onChanged: (_) => setState(() {})),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _moneyField(
                controller: _subsidyCtrl,
                label: s.subsidyLabel,
                icon: Icons.card_giftcard_outlined,
                onChanged: (_) => setState(() {})),
          ],
        ),
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${AppSettings.instance.currency.symbol} ',
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool decimal = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _jobCard(L10n s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.jobOptional,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _jobCtrl,
              decoration: InputDecoration(
                labelText: s.jobExample,
                prefixIcon: const Icon(Icons.work_outline),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: s.commonJobs
                  .where((j) => j.trim().isNotEmpty)
                  .map((j) => ActionChip(
                        label: Text(j, style: const TextStyle(fontSize: 12)),
                        onPressed: () =>
                            setState(() => _jobCtrl.text = j.trim()),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: s.noteOptional,
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalBar(L10n s) {
    final c = AppSettings.instance.currency;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tones.onPrimarySoft(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _sumLine('${s.normalPay} ${c.format(_base)}'),
          if (_payType == PayService.typeHourly)
            _sumLine('${s.overtimePayLabel} ${c.format(_overtimePay)}'),
          _sumLine('${s.subsidyShort} ${c.format(_subsidy)}'),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.entryTotal,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(PayService.money(_total),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Tones.primaryInk(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );

  Widget _tapRow(IconData icon, String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../services/app_settings.dart';
import '../services/data_notifier.dart';
import '../services/pay_service.dart';
import '../theme.dart';

/// 账本管理页：新建、编辑、删除账本，切换当前账本。
class LedgerManagePage extends StatefulWidget {
  const LedgerManagePage({super.key});

  @override
  State<LedgerManagePage> createState() => _LedgerManagePageState();
}

class _LedgerManagePageState extends State<LedgerManagePage> {
  List<Ledger> _ledgers = [];

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
    final list = await DatabaseHelper.instance.getLedgers();
    if (!mounted) return;
    setState(() => _ledgers = list);
  }

  Future<void> _setCurrent(Ledger l) async {
    await DatabaseHelper.instance.setCurrentLedger(l.id!);
    DataNotifier.instance.notify();
    _load();
  }

  Future<void> _delete(Ledger l, L10n s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteLedgerTitle(l.name)),
        content: Text(s.deleteLedgerDesc),
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
    if (ok != true) return;
    await DatabaseHelper.instance.deleteLedger(l.id!);
    DataNotifier.instance.notify();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.employerManage)),
      body: _ledgers.isEmpty
          ? Center(
              child: Text(s.addEmployerHint,
                  style: const TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _ledgers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final l = _ledgers[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Tones.onPrimarySoft(context),
                      child: Text(
                          l.name.isNotEmpty ? l.name.substring(0, 1) : '?',
                          style: TextStyle(color: Tones.primaryInk(context))),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(l.name)),
                        if (l.isCurrent == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Tones.onPrimarySoft(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(s.current,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Tones.primaryInk(context))),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(l.localizedRateText(s)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showEditor(l, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.grey),
                          onPressed: () => _delete(l, s),
                        ),
                      ],
                    ),
                    onTap: () => _setCurrent(l),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(null, s),
        child: const Icon(Icons.add),
      ),
    );
  }

  // 新建 / 编辑账本弹窗
  Future<void> _showEditor(Ledger? ledger, L10n s) async {
    final nameCtrl = TextEditingController(text: ledger?.name ?? '');
    var payType = ledger?.payType ?? PayService.typeHourly;
    final rateCtrl = TextEditingController(text: _rateText(ledger, payType));

    String rateLabel() {
      switch (payType) {
        case PayService.typeHourly:
          return s.hourlyLabel;
        case PayService.typeDaily:
          return s.dailyLabel;
        default:
          return s.pieceLabel;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ledger == null ? s.addEmployerSheet : s.editEmployerSheet,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: s.employerNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.payMethod, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: PayService.typeHourly, label: Text(s.hourly)),
                  ButtonSegment(value: PayService.typeDaily, label: Text(s.daily)),
                  ButtonSegment(value: PayService.typePiece, label: Text(s.piece)),
                ],
                selected: {payType},
                onSelectionChanged: (set) {
                  setSheetState(() {
                    payType = set.first;
                    rateCtrl.text = _rateText(ledger, payType);
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: rateLabel(),
                  prefixText: '${AppSettings.instance.currency.symbol} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final rate = double.tryParse(rateCtrl.text.trim());
                    if (name.isEmpty) {
                      _toast(s.toastName);
                      return;
                    }
                    if (rate == null || rate <= 0) {
                      _toast(s.toastRateInvalid);
                      return;
                    }
                    final l = Ledger(
                      id: ledger?.id,
                      name: name,
                      payType: payType,
                      hourlyRate:
                          payType == PayService.typeHourly ? rate : 0,
                      dailyRate:
                          payType == PayService.typeDaily ? rate : 0,
                      pieceRate:
                          payType == PayService.typePiece ? rate : 0,
                      isCurrent: ledger?.isCurrent ??
                          (_ledgers.isEmpty ? 1 : 0),
                      colorIndex: ledger?.colorIndex ?? 0,
                      createdAt:
                          ledger?.createdAt ?? DateTime.now().toString(),
                    );
                    if (ledger == null) {
                      await DatabaseHelper.instance.insertLedger(l);
                    } else {
                      await DatabaseHelper.instance.updateLedger(l);
                    }
                    DataNotifier.instance.notify();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _load();
  }

  String _rateText(Ledger? ledger, int payType) {
    if (ledger == null) return '';
    switch (payType) {
      case PayService.typeHourly:
        return ledger.hourlyRate.toString();
      case PayService.typeDaily:
        return ledger.dailyRate.toString();
      default:
        return ledger.pieceRate.toString();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

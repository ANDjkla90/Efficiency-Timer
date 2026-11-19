import '../l10n/app_strings.dart';
import '../models/work_record.dart';
import 'pay_service.dart';

/// 结算对账的纯逻辑：周期边界、待结算筛选、账单文本。
/// 不碰数据库、不碰 UI，方便单元测试。
class SettlementService {
  /// 当月 1 日 00:00
  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

  /// 下月 1 日 00:00（作为「不含」的上界，跨年自动进位）
  static DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1);

  /// 本月周期 [起, 止)
  static (DateTime, DateTime) thisMonth(DateTime now) =>
      (monthStart(now), nextMonthStart(now));

  /// 上月周期 [起, 止)
  static (DateTime, DateTime) lastMonth(DateTime now) {
    final start = DateTime(now.year, now.month - 1);
    return (start, monthStart(now));
  }

  /// 记录是否落在 [from, to) 内（按开始时间，含跨天班次的起始日）
  static bool inRange(WorkRecord r, DateTime from, DateTime to) =>
      !r.startTime.isBefore(from) && r.startTime.isBefore(to);

  /// 该周期内还没结算过的记录（按时间正序，账单顺序好看）
  static List<WorkRecord> unsettledInRange(
    Iterable<WorkRecord> records, {
    required int ledgerId,
    required DateTime from,
    required DateTime to,
  }) {
    final list = records
        .where((r) =>
            r.ledgerId == ledgerId &&
            r.settlementId == null &&
            inRange(r, from, to))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  static double sum(Iterable<WorkRecord> records) =>
      records.fold(0.0, (s, r) => s + PayService.total(r));

  /// 账单文本：复制给雇主对账用，纯文本、不含表格符号，微信里不会乱码。
  ///
  /// [totalOverride] 传入结算单生成时的金额快照。历史结算单复制账单时必须传，
  /// 否则会把「事后改过单价」的记录重新求和，和当初结清的金额对不上。
  static String buildBillText({
    required String employer,
    required DateTime from,
    required DateTime to,
    required List<WorkRecord> records,
    required L10n s,
    double? totalOverride,
  }) {
    final sorted = [...records]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final endInclusive = to.subtract(const Duration(days: 1));
    final total = totalOverride ?? sum(sorted);
    final buf = StringBuffer()
      ..writeln(s.settlementBillTitleLine(employer))
      ..writeln(s.settlementBillPeriodLine(s.dateOnly(from), s.dateOnly(endInclusive)))
      ..writeln(s.settlementBillCountLine(sorted.length))
      ..writeln('');
    for (final r in sorted) {
      buf.writeln(s.settlementBillEntryLine(
        s.dateOnly(r.startTime),
        PayService.quantityText(r, s),
        PayService.money(PayService.total(r)),
      ));
    }
    buf
      ..writeln('——————————')
      ..writeln(s.settlementBillTotalLine(PayService.money(total)))
      ..write(s.settlementBillFooter);
    return buf.toString();
  }
}

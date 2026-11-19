import '../models/work_record.dart';
import 'app_settings.dart';

/// 算钱服务：把工时 / 件数 / 天数按单价换算成工钱，统一口径供全 App 使用。
/// 本笔合计 = 正常工资 + 加班费 + 补贴。
class PayService {
  static const int typeHourly = 0; // 时薪
  static const int typeDaily = 1; // 日薪
  static const int typePiece = 2; // 计件

  /// 数量列的含义随计薪方式变化：时薪用 durationMinutes，
  /// 日薪用 pieceCount 存「天数」，计件用 pieceCount 存「件数」。
  /// 日薪历史数据 pieceCount = 0，按 1 天处理。
  static int quantityOf(WorkRecord r) {
    switch (r.payType) {
      case typeDaily:
        return r.pieceCount > 0 ? r.pieceCount : 1;
      case typePiece:
        return r.pieceCount;
      default:
        return r.durationMinutes;
    }
  }

  /// 正常工资：时薪 × 工时 / 60；日薪 × 天数；计件单价 × 件数
  static double baseWage(WorkRecord r) {
    switch (r.payType) {
      case typeHourly:
        return r.rate * r.durationMinutes / 60.0;
      case typeDaily:
        return r.rate * quantityOf(r);
      case typePiece:
        return r.rate * r.pieceCount;
      default:
        return 0;
    }
  }

  /// 加班费：加班时薪 × (加班分钟 / 60)
  static double overtimePay(WorkRecord r) {
    if (r.overtimeMinutes <= 0 || r.overtimeRate <= 0) return 0;
    return r.overtimeRate * r.overtimeMinutes / 60.0;
  }

  /// 本笔合计
  static double total(WorkRecord r) => baseWage(r) + overtimePay(r) + r.subsidy;

  /// 记录「数量」的展示文字：时薪显示工时，日薪显示天数，计件显示件数。
  static String quantityText(WorkRecord r, L10n s) {
    switch (r.payType) {
      case typeDaily:
        return s.daysCount(quantityOf(r));
      case typePiece:
        return s.piecesCount(r.pieceCount);
      default:
        return s.duration(r.durationMinutes + r.overtimeMinutes);
    }
  }

  /// 金额展示：按当前国家/地区对应的货币符号、名称和格式输出。
  /// 只影响显示，不改动任何计算与存储数值。
  static String money(double v) => AppSettings.instance.currency.format(v);

  /// 显式按指定货币格式化（用于设置页预览等）。
  static String moneyIn(double v, CurrencyDef currency) => currency.format(v);

  /// 汇总一批记录的工作量。三类计薪方式的口径不同，不能相加：
  /// 时薪累计分钟、日薪累计天数、计件累计件数。
  static WorkTotals totalsOf(Iterable<WorkRecord> records) {
    final t = WorkTotals();
    for (final r in records) {
      switch (r.payType) {
        case typeDaily:
          t.dailyDays += quantityOf(r);
          break;
        case typePiece:
          t.pieces += r.pieceCount;
          break;
        default:
          t.hourlyMinutes += r.durationMinutes + r.overtimeMinutes;
      }
    }
    return t;
  }
}

/// 一批记录按计薪方式拆开的工作量合计。
class WorkTotals {
  int hourlyMinutes = 0; // 时薪：累计工时（含加班）
  int dailyDays = 0; // 日薪：累计天数
  int pieces = 0; // 计件：累计件数

  bool get isEmpty => hourlyMinutes == 0 && dailyDays == 0 && pieces == 0;
}

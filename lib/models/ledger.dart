import '../services/app_settings.dart';

/// 账本模型
/// 一个账本代表一个「老板 / 工地 / 店铺」，按不同计薪方式算工钱。
/// 计薪方式：0=时薪  1=日薪  2=计件
class Ledger {
  int? id;
  String name; // 账本名称，如「张三工地」
  int payType; // 计薪方式：0=时薪  1=日薪  2=计件
  double hourlyRate; // 时薪单价（元/小时），payType=0 时有效
  double dailyRate; // 日薪（元/天），payType=1 时有效
  double pieceRate; // 计件单价（元/件），payType=2 时有效
  int isCurrent; // 是否当前账本：0=否 1=是
  int colorIndex; // 颜色序号（用于列表区分）
  String createdAt; // 创建时间（字符串，便于展示）

  Ledger({
    this.id,
    required this.name,
    required this.payType,
    this.hourlyRate = 0,
    this.dailyRate = 0,
    this.pieceRate = 0,
    this.isCurrent = 0,
    this.colorIndex = 0,
    required this.createdAt,
  });

  /// 本地化的「计薪方式 · 单价」副标题，供雇主列表展示。
  String localizedRateText(L10n s) {
    final c = AppSettings.instance.currency;
    switch (payType) {
      case 0:
        return '${s.hourly} · ${c.format(hourlyRate)}${s.perHour}';
      case 1:
        return '${s.daily} · ${c.format(dailyRate)}${s.perDay}';
      default:
        return '${s.piece} · ${c.format(pieceRate)}${s.perPiece}';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'pay_type': payType,
        'hourly_rate': hourlyRate,
        'daily_rate': dailyRate,
        'piece_rate': pieceRate,
        'is_current': isCurrent,
        'color_index': colorIndex,
        'created_at': createdAt,
      };

  factory Ledger.fromMap(Map<String, dynamic> map) => Ledger(
        id: map['id'],
        name: map['name'],
        payType: map['pay_type'],
        hourlyRate: (map['hourly_rate'] as num?)?.toDouble() ?? 0,
        dailyRate: (map['daily_rate'] as num?)?.toDouble() ?? 0,
        pieceRate: (map['piece_rate'] as num?)?.toDouble() ?? 0,
        isCurrent: map['is_current'] ?? 0,
        colorIndex: map['color_index'] ?? 0,
        createdAt: map['created_at'],
      );
}

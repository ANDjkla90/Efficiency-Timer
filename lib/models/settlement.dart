/// 结算单：某雇主在某段周期内的一批记录的结算凭证。
/// 金额是生成当时的快照，之后改记录不会改动历史结算单。
class Settlement {
  int? id;
  int ledgerId;
  DateTime periodStart; // 周期起始（含）
  DateTime periodEnd; // 周期结束（不含，便于用 < 比较）
  double amount; // 结算金额快照
  int recordCount; // 纳入的记录笔数
  int createdAt; // 生成时间（毫秒）

  Settlement({
    this.id,
    required this.ledgerId,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    this.recordCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'period_start': periodStart.millisecondsSinceEpoch,
        'period_end': periodEnd.millisecondsSinceEpoch,
        'amount': amount,
        'record_count': recordCount,
        'created_at': createdAt,
      };

  factory Settlement.fromMap(Map<String, dynamic> map) => Settlement(
        id: map['id'] as int?,
        ledgerId: map['ledger_id'] ?? 0,
        periodStart:
            DateTime.fromMillisecondsSinceEpoch(map['period_start'] ?? 0),
        periodEnd: DateTime.fromMillisecondsSinceEpoch(map['period_end'] ?? 0),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        recordCount: map['record_count'] ?? 0,
        createdAt: map['created_at'] ?? 0,
      );
}

/// 工时记账记录模型
/// 每一笔 = 一次/一天的活：日期 + 起止时间(工时) + 小时工资 + 加班 + 补贴 + 工种(雇主)。
/// 本笔工钱由 PayService 统一算出：正常工资 + 加班费 + 补贴。
class WorkRecord {
  int? id;
  int ledgerId; // 所属雇主/账本
  int payType; // 计薪方式快照：0=时薪 1=日薪 2=计件（保留兼容，主流程为时薪）
  DateTime startTime; // 工作日期 + 开始时间（日薪/计件固定当天 00:00，不含时刻含义）
  DateTime endTime; // 结束时间
  int durationMinutes; // 正常工时（分钟，已扣除休息，时薪用）
  int pieceCount; // 数量：计件=件数，日薪=天数（0 视为 1 天）
  double rate; // 单价快照：时薪/日薪/件单价
  int overtimeMinutes; // 加班工时（分钟），0 表示无加班
  double overtimeRate; // 加班小时工资（元/小时），0 表示无加班
  double subsidy; // 补贴（元），如餐补、车补、夜班补贴
  String jobType; // 工种，如「搬运」「安装」「保洁」
  double amount; // 本笔合计 = 正常工资 + 加班费 + 补贴
  String note; // 备注
  int breakMinutes; // 休息扣除（分钟），仅时薪用；记录它是为了再次编辑时能还原
  int? settlementId; // 已归入哪张结算单；null=未结算
  DateTime createdAt; // 创建时间

  WorkRecord({
    this.id,
    required this.ledgerId,
    this.payType = 0,
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 0,
    this.pieceCount = 0,
    this.rate = 0,
    this.overtimeMinutes = 0,
    this.overtimeRate = 0,
    this.subsidy = 0,
    this.jobType = '',
    this.amount = 0,
    this.note = '',
    this.breakMinutes = 0,
    this.settlementId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'pay_type': payType,
        'start_time': startTime.millisecondsSinceEpoch,
        'end_time': endTime.millisecondsSinceEpoch,
        'duration_minutes': durationMinutes,
        'piece_count': pieceCount,
        'rate': rate,
        'overtime_minutes': overtimeMinutes,
        'overtime_rate': overtimeRate,
        'subsidy': subsidy,
        'job_type': jobType,
        'amount': amount,
        'note': note,
        'break_minutes': breakMinutes,
        'settlement_id': settlementId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory WorkRecord.fromMap(Map<String, dynamic> map) => WorkRecord(
        id: map['id'],
        ledgerId: map['ledger_id'] ?? 0,
        payType: map['pay_type'] ?? 0,
        startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] ?? 0),
        endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] ?? 0),
        durationMinutes: map['duration_minutes'] ?? 0,
        pieceCount: map['piece_count'] ?? 0,
        rate: (map['rate'] as num?)?.toDouble() ?? 0,
        overtimeMinutes: map['overtime_minutes'] ?? 0,
        overtimeRate: (map['overtime_rate'] as num?)?.toDouble() ?? 0,
        subsidy: (map['subsidy'] as num?)?.toDouble() ?? 0,
        jobType: map['job_type'] ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        note: map['note'] ?? '',
        // v3 之前没有这两列：旧备份直接缺 key，按「无休息扣除 / 未结算」处理
        breakMinutes: map['break_minutes'] ?? 0,
        settlementId: map['settlement_id'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      );

  /// 复制一份（撤销删除后重新入库用，id 置空让数据库重新分配）
  WorkRecord copyWithoutId() => WorkRecord.fromMap({...toMap(), 'id': null});
}

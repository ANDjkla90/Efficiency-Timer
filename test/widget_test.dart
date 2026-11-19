import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigongshi/config/currency_config.dart';
import 'package:jigongshi/l10n/app_strings.dart';
import 'package:jigongshi/models/ledger.dart';
import 'package:jigongshi/models/settlement.dart';
import 'package:jigongshi/models/work_record.dart';
import 'package:jigongshi/services/app_lock.dart';
import 'package:jigongshi/services/backup_service.dart';
import 'package:jigongshi/services/pay_service.dart';
import 'package:jigongshi/services/settlement_service.dart';
import 'package:jigongshi/theme.dart';
import 'package:jigongshi/utils/time_utils.dart';

void main() {
  test('主题构建正常（浅色/深色 + 多套主色）', () {
    final primaries = <Color>{};
    for (final seed in AppSettingsSeed.sample) {
      final light = buildAppTheme(seedColor: seed, brightness: Brightness.light);
      final dark = buildAppTheme(seedColor: seed, brightness: Brightness.dark);
      expect(light.colorScheme.primary, isNotNull);
      expect(light.useMaterial3, isTrue);
      expect(dark.colorScheme.brightness, Brightness.dark);
      primaries.add(light.colorScheme.primary);
    }
    // 不同种子色应产生不同的主色，证明配色切换确实生效
    expect(primaries.length, AppSettingsSeed.sample.length);
  });

  test('中英文案与本地化格式正确', () {
    final zh = L10n(true);
    final en = L10n(false);
    expect(zh.todayWage, '今日工资');
    expect(en.todayWage, "Today's Pay");
    expect(zh.duration(150), '2小时30分');
    expect(en.duration(150), '2h 30m');
    expect(zh.yearMonthLabel('2026-11'), '2026年11月');
    expect(en.yearMonthLabel('2026-11'), 'Nov 2026');
  });

  test('应用名称已改为驰马时记', () {
    expect(L10n(true).appTitle, '驰马时记');
    expect(L10n(false).appTitle, 'Chima TimeLog');
    expect(L10n(true).backupFileNamePrefix, '驰马时记备份');
  });

  group('国家/地区 → 货币集中配置', () {
    test('已配置国家返回对应货币，格式按货币规则', () {
      expect(currencyForCountry('CN').code, 'CNY');
      expect(currencyForCountry('us').code, 'USD');
      expect(currencyForCountry('DE').code, 'EUR');
      expect(currencyForCountry('JP').code, 'JPY');
      expect(currencyForCountry('TW').code, 'TWD');

      expect(PayService.moneyIn(1234.5, currencyForCountry('CN')), '¥1,234.50');
      expect(PayService.moneyIn(1234.5, currencyForCountry('US')), '\$1,234.50');
      expect(PayService.moneyIn(1234.5, currencyForCountry('JP')), '¥1,235');
      expect(PayService.moneyIn(1234.5, currencyForCountry('DE')), '1.234,50 €');
    });

    test('未配置/空地区回退默认货币，且可指定默认货币', () {
      expect(currencyForCountry('XX').code, 'CNY');
      expect(currencyForCountry(null).code, 'CNY');
      expect(currencyForCountry('').code, 'CNY');
      expect(
        currencyForCountry('XX', defaultCurrencyCode: 'GBP').code,
        'GBP',
      );
    });

    test('货币展示名称与地区名称中英齐全', () {
      final zh = L10n(true);
      final en = L10n(false);
      final cny = currencyByCode('CNY');
      expect(cny.name(zh.isZh), '人民币');
      expect(cny.name(en.isZh), 'Chinese Yuan');
      expect(regionByCode('CN')!.name(zh.isZh), '中国');
      expect(regionByCode('CN')!.name(en.isZh), 'China');
      expect(regionByCode('HK')!.name(zh.isZh), '中国香港');
      expect(zh.currencyRegionSummary('中国', '人民币', '¥'), '中国 · 人民币 ¥');
    });

    test('默认货币钉人民币，英文系统不会自动变美元', () {
      // AppSettings 字段默认 countryManual + 'CN'（见 app_settings.dart）
      expect(currencyForCountry('CN', defaultCurrencyCode: 'CNY').symbol, '¥');
      expect(kDefaultCurrencyCode, 'CNY');
    });

    test('金额计算口径不受货币展示影响', () {
      final cny = currencyForCountry('CN');
      final usd = currencyForCountry('US');
      // 同一数值，仅展示符号/格式不同，数值本身一致
      expect(cny.format(88.5).contains('88.50'), isTrue);
      expect(usd.format(88.5).contains('88.50'), isTrue);
    });
  });

  group('工时计算（跨天）', () {
    test('白天正常班：09:00 → 18:00 = 540 分钟', () {
      expect(minutesBetweenClocks(clockMinutes(9, 0), clockMinutes(18, 0)), 540);
      expect(crossesMidnight(clockMinutes(9, 0), clockMinutes(18, 0)), isFalse);
    });

    test('夜班 22:00 → 次日 06:00 = 480 分钟（不是 0）', () {
      final start = clockMinutes(22, 0);
      final end = clockMinutes(6, 0);
      expect(minutesBetweenClocks(start, end), 480);
      expect(crossesMidnight(start, end), isTrue);
    });

    test('跨天但只差 2 分钟：23:59 → 00:01 = 2', () {
      expect(minutesBetweenClocks(clockMinutes(23, 59), clockMinutes(0, 1)), 2);
    });

    test('起止相同按 0 分钟处理，避免手滑记成 24 小时', () {
      expect(minutesBetweenClocks(clockMinutes(22, 0), clockMinutes(22, 0)), 0);
    });

    test('结束时刻跨天时要落到次日，日期不能和开始同一天', () {
      final r = rangeFromClock(
        DateTime(2026, 11, 17),
        clockMinutes(22, 0),
        clockMinutes(6, 0),
      );
      expect(r.start, DateTime(2026, 11, 17, 22, 0));
      expect(r.end, DateTime(2026, 11, 18, 6, 0));
      expect(r.end.difference(r.start).inMinutes, 480);
    });

    test('填工时模式：结束时刻 = 开始 + 工时，两者永远一致', () {
      final r = rangeFromDuration(
        DateTime(2026, 11, 18),
        clockMinutes(20, 0),
        300,
      );
      expect(r.start, DateTime(2026, 11, 18, 20, 0));
      expect(r.end, DateTime(2026, 11, 19, 1, 0));
      expect(r.end.difference(r.start).inMinutes, 300);
    });
  });

  group('算账口径', () {
    WorkRecord rec({
      int payType = 0,
      int durationMinutes = 0,
      int pieceCount = 0,
      double rate = 0,
      int overtimeMinutes = 0,
      double overtimeRate = 0,
      double subsidy = 0,
      DateTime? start,
      DateTime? end,
    }) =>
        WorkRecord(
          ledgerId: 1,
          payType: payType,
          startTime: start ?? DateTime(2026, 11, 18, 9),
          endTime: end ?? DateTime(2026, 11, 18, 17),
          durationMinutes: durationMinutes,
          pieceCount: pieceCount,
          rate: rate,
          overtimeMinutes: overtimeMinutes,
          overtimeRate: overtimeRate,
          subsidy: subsidy,
          createdAt: DateTime(2026, 11, 18, 18),
        );

    test('时薪：时薪 × 工时', () {
      final r = rec(durationMinutes: 480, rate: 25.5);
      expect(PayService.baseWage(r), closeTo(204.0, 0.001));
      expect(PayService.total(r), closeTo(204.0, 0.001));
    });

    test('日薪：一天一价，与工时无关', () {
      final r = rec(payType: PayService.typeDaily, durationMinutes: 120, rate: 300);
      expect(PayService.baseWage(r), 300);
      expect(PayService.total(r), 300);
    });

    test('日薪多天：天数 × 日薪', () {
      final r = rec(payType: PayService.typeDaily, pieceCount: 3, rate: 300);
      expect(PayService.quantityOf(r), 3);
      expect(PayService.baseWage(r), 900);
    });

    test('计件：单价 × 件数', () {
      final r = rec(
          payType: PayService.typePiece, pieceCount: 120, rate: 2.5);
      expect(PayService.baseWage(r), 300);
      expect(PayService.total(r), 300);
    });

    test('加班与补贴计入合计', () {
      final r = rec(
        durationMinutes: 480,
        rate: 30,
        overtimeMinutes: 90,
        overtimeRate: 45,
        subsidy: 20,
      );
      expect(PayService.overtimePay(r), closeTo(67.5, 0.001));
      expect(PayService.total(r), closeTo(327.5, 0.001));
    });

    test('跨天班次：22:00 → 06:00 由时间算出 480 分钟，再按 8 小时算钱', () {
      // 用生产代码同一套函数算时长，而不是直接把 480 塞进记录（假用例）
      final range = rangeFromClock(
        DateTime(2026, 11, 17),
        clockMinutes(22, 0),
        clockMinutes(6, 0),
      );
      final minutes = minutesBetweenClocks(
        minuteOfDay(range.start),
        minuteOfDay(range.end),
      );
      final r = rec(
        start: range.start,
        end: range.end,
        durationMinutes: minutes,
        rate: 25.5,
      );
      expect(minutes, 480);
      expect(PayService.baseWage(r), closeTo(204.0, 0.001));
    });

    test('数量展示：时薪显示工时、日薪显示天数、计件显示件数', () {
      final zh = L10n(true);
      expect(PayService.quantityText(rec(durationMinutes: 480), zh), '8小时');
      expect(
        PayService.quantityText(
            rec(payType: PayService.typeDaily, pieceCount: 2), zh),
        '2 天',
      );
      expect(
        PayService.quantityText(
            rec(payType: PayService.typePiece, pieceCount: 120), zh),
        '120 件',
      );
    });
  });

  group('午休扣除', () {
    test('09:00-18:00 扣 60 分钟午休 = 480 分钟，按 8 小时算钱', () {
      final span = minutesBetweenClocks(clockMinutes(9, 0), clockMinutes(18, 0));
      final paid = paidMinutes(span, 60);
      expect(span, 540);
      expect(paid, 480);
      final r = WorkRecord(
        ledgerId: 1,
        startTime: DateTime(2026, 11, 18, 9),
        endTime: DateTime(2026, 11, 18, 18),
        durationMinutes: paid,
        rate: 25.5,
        breakMinutes: 60,
        createdAt: DateTime(2026, 11, 18, 18),
      );
      expect(PayService.baseWage(r), closeTo(204.0, 0.001));
    });

    test('不扣休息时与旧口径一致', () {
      expect(paidMinutes(540, 0), 540);
      expect(paidMinutes(480, 90), 390);
    });

    test('休息填超了按 0 处理，不会算出负工资', () {
      expect(paidMinutes(540, 600), 0);
      expect(paidMinutes(0, 30), 0);
    });
  });

  group('结算对账', () {
    WorkRecord rec({
      int id = 1,
      int ledgerId = 1,
      int payType = 0,
      int durationMinutes = 480,
      int pieceCount = 0,
      double rate = 25,
      double subsidy = 0,
      int? settlementId,
      required DateTime day,
    }) =>
        WorkRecord(
          id: id,
          ledgerId: ledgerId,
          payType: payType,
          startTime: day,
          endTime: day,
          durationMinutes: durationMinutes,
          pieceCount: pieceCount,
          rate: rate,
          subsidy: subsidy,
          settlementId: settlementId,
          createdAt: day,
        );

    test('本月周期：1 日 00:00 到下月 1 日 00:00（不含）', () {
      final (from, to) = SettlementService.thisMonth(DateTime(2026, 11, 18));
      expect(from, DateTime(2026, 11, 1));
      expect(to, DateTime(2026, 12, 1));
    });

    test('上月周期跨年正确：1 月的上一个月是去年 12 月', () {
      final (from, to) = SettlementService.lastMonth(DateTime(2026, 1, 15));
      expect(from, DateTime(2025, 12, 1));
      expect(to, DateTime(2026, 1, 1));
    });

    test('只挑当前雇主、当前周期、且没结算过的记录，按时间正序', () {
      final records = [
        rec(id: 1, day: DateTime(2026, 11, 3), durationMinutes: 480),
        rec(id: 2, day: DateTime(2026, 11, 1), durationMinutes: 240),
        rec(id: 3, day: DateTime(2026, 12, 1), durationMinutes: 480), // 下月
        rec(id: 4, day: DateTime(2026, 11, 5), settlementId: 9), // 已结算
        rec(id: 5, ledgerId: 2, day: DateTime(2026, 11, 6)), // 别的雇主
      ];
      final (from, to) = SettlementService.thisMonth(DateTime(2026, 11, 18));
      final picked = SettlementService.unsettledInRange(
        records,
        ledgerId: 1,
        from: from,
        to: to,
      );
      expect(picked.map((r) => r.id), [2, 1]);
      // 4 小时 × 25 + 8 小时 × 25 = 100 + 200
      expect(SettlementService.sum(picked), closeTo(300.0, 0.001));
    });

    test('账单文本包含周期、笔数、明细和合计', () {
      final records = [
        rec(id: 1, day: DateTime(2026, 11, 3), durationMinutes: 480, rate: 25),
        rec(
          id: 2,
          day: DateTime(2026, 11, 4),
          payType: PayService.typeDaily,
          durationMinutes: 0,
          pieceCount: 2,
          rate: 300,
        ),
      ];
      final text = SettlementService.buildBillText(
        employer: '张三工地',
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 12, 1),
        records: records,
        s: const L10n(true),
      );
      expect(text, contains('张三工地'));
      expect(text, contains('共 2 笔'));
      expect(text, contains('8小时'));
      expect(text, contains('2 天'));
      // 200 + 600 = 800
      expect(text, contains('800.00'));
    });

    test('结算单与记录序列化往返不丢字段', () {
      final st = Settlement(
        id: 7,
        ledgerId: 3,
        periodStart: DateTime(2026, 11, 1),
        periodEnd: DateTime(2026, 12, 1),
        amount: 1234.5,
        recordCount: 12,
        createdAt: 1763000000000,
      );
      final back = Settlement.fromMap(st.toMap());
      expect(back.id, 7);
      expect(back.ledgerId, 3);
      expect(back.periodStart, st.periodStart);
      expect(back.periodEnd, st.periodEnd);
      expect(back.amount, 1234.5);
      expect(back.recordCount, 12);
      expect(back.createdAt, st.createdAt);
    });
    test('历史账单用结算快照金额，不按记录当前值重新求和', () {
      // 记录事后被改贵了（现在值 240），但结算单当时是 270
      final records = [
        rec(id: 1, day: DateTime(2026, 11, 3), durationMinutes: 480, rate: 30),
      ];
      final snapshot = SettlementService.buildBillText(
        employer: '张三工地',
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 12, 1),
        records: records,
        s: const L10n(true),
        totalOverride: 270,
      );
      expect(snapshot, contains('合计应结：¥270.00'));

      final live = SettlementService.buildBillText(
        employer: '张三工地',
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 12, 1),
        records: records,
        s: const L10n(true),
      );
      expect(live, contains('合计应结：¥240.00'));
    });
  });

  group('应用锁 PIN', () {
    test('同一 PIN + 同一盐校验值稳定，换盐就不同', () {
      final a = AppLock.hashPin('salt-a', '1234');
      final b = AppLock.hashPin('salt-a', '1234');
      final c = AppLock.hashPin('salt-b', '1234');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, 64); // SHA-256 十六进制
    });

    test('PIN 只接受 4 位或 6 位纯数字', () {
      expect(AppLock.isValidPin('1234'), isTrue);
      expect(AppLock.isValidPin('123456'), isTrue);
      expect(AppLock.isValidPin('123'), isFalse);
      expect(AppLock.isValidPin('12345'), isFalse);
      expect(AppLock.isValidPin('12a4'), isFalse);
      expect(AppLock.isValidPin(''), isFalse);
      expect(AppLock.isValidPin('1234', expectedLength: 6), isFalse);
    });

    test('不同 PIN 的校验值不同，且不可从校验值反推', () {
      expect(AppLock.hashPin('s', '1234'), isNot(AppLock.hashPin('s', '1235')));
      expect(AppLock.hashPin('s', '1234').contains('1234'), isFalse);
    });

    test('连续输错的延时：前 4 次不延时，第 5 次 1 秒，之后翻倍，封顶 30 秒', () {
      expect(AppLock.throttleFor(0), Duration.zero);
      expect(AppLock.throttleFor(4), Duration.zero);
      expect(AppLock.throttleFor(5), const Duration(seconds: 1));
      expect(AppLock.throttleFor(6), const Duration(seconds: 2));
      expect(AppLock.throttleFor(7), const Duration(seconds: 4));
      expect(AppLock.throttleFor(8), const Duration(seconds: 8));
      expect(AppLock.throttleFor(9), const Duration(seconds: 16));
      // 32 秒会被封顶到 30 秒
      expect(AppLock.throttleFor(10), const Duration(seconds: 30));
      expect(AppLock.throttleFor(999), const Duration(seconds: 30));
    });
  });

  group('备份导出 / 导入', () {
    Ledger sampleLedger() => Ledger(
          id: 3,
          name: '张三工地',
          payType: 0,
          hourlyRate: 25.5,
          dailyRate: 0,
          pieceRate: 0,
          isCurrent: 1,
          colorIndex: 2,
          createdAt: '2026-11-01T08:00:00.000',
        );

    WorkRecord sampleRecord() => WorkRecord(
          id: 11,
          ledgerId: 3,
          payType: 0,
          startTime: DateTime(2026, 11, 17, 22),
          endTime: DateTime(2026, 11, 18, 6),
          durationMinutes: 480,
          pieceCount: 0,
          rate: 25.5,
          overtimeMinutes: 30,
          overtimeRate: 38.0,
          subsidy: 20.0,
          jobType: '夜班搬运',
          amount: 243.0,
          note: '跨天夜班，含餐补',
          createdAt: DateTime(2026, 11, 18, 7, 10),
        );

    test('导出的 JSON 经解析后字段全部无损', () {
      final json = BackupService.buildBackupJson(
        ledgers: [sampleLedger()],
        records: [sampleRecord()],
        now: DateTime(2026, 11, 18, 20),
      );
      expect(json, contains(BackupService.formatTag));

      final parsed = BackupService.parseBackupJson(json);
      expect(parsed.ledgers.length, 1);
      expect(parsed.records.length, 1);

      final l = parsed.ledgers.single;
      final src = sampleLedger();
      expect(l.id, src.id);
      expect(l.name, src.name);
      expect(l.payType, src.payType);
      expect(l.hourlyRate, src.hourlyRate);
      expect(l.isCurrent, src.isCurrent);
      expect(l.colorIndex, src.colorIndex);
      expect(l.createdAt, src.createdAt);

      final r = parsed.records.single;
      final rs = sampleRecord();
      expect(r.id, rs.id);
      expect(r.ledgerId, rs.ledgerId);
      expect(r.payType, rs.payType);
      expect(r.startTime, rs.startTime);
      expect(r.endTime, rs.endTime);
      expect(r.durationMinutes, 480);
      expect(r.rate, 25.5);
      expect(r.overtimeMinutes, 30);
      expect(r.overtimeRate, 38.0);
      expect(r.subsidy, 20.0);
      expect(r.jobType, '夜班搬运');
      expect(r.note, '跨天夜班，含餐补');
      expect(r.amount, 243.0);
      expect(r.createdAt, rs.createdAt);
    });

    test('恢复后算钱口径与备份前一致（单价快照不变）', () {
      final before = sampleRecord();
      final parsed = BackupService.parseBackupJson(
        BackupService.buildBackupJson(ledgers: [], records: [before]),
      );
      expect(PayService.total(parsed.records.single),
          closeTo(PayService.total(before), 0.001));
    });

    test('损坏的备份文件抛 FormatException，不会写入数据库', () {
      expect(() => BackupService.parseBackupJson('not json'),
          throwsA(isA<FormatException>()));
      expect(() => BackupService.parseBackupJson('{"foo":1}'),
          throwsA(isA<FormatException>()));
      expect(() => BackupService.parseBackupJson('{"ledgers":"x","records":[]}'),
          throwsA(isA<FormatException>()));
    });

    test('休息扣除、结算关系、结算单本身都能随备份往返', () {
      final r = WorkRecord(
        id: 21,
        ledgerId: 3,
        payType: 0,
        startTime: DateTime(2026, 11, 3, 9),
        endTime: DateTime(2026, 11, 3, 18),
        durationMinutes: 480,
        rate: 25,
        amount: 200,
        breakMinutes: 60,
        settlementId: 5,
        createdAt: DateTime(2026, 11, 3, 19),
      );
      final st = Settlement(
        id: 5,
        ledgerId: 3,
        periodStart: DateTime(2026, 11, 1),
        periodEnd: DateTime(2026, 12, 1),
        amount: 200,
        recordCount: 1,
        createdAt: 1763000000000,
      );
      final parsed = BackupService.parseBackupJson(
        BackupService.buildBackupJson(
          ledgers: [],
          records: [r],
          settlements: [st],
        ),
      );
      expect(parsed.records.single.breakMinutes, 60);
      expect(parsed.records.single.settlementId, 5);
      expect(parsed.settlements.single.id, 5);
      expect(parsed.settlements.single.amount, 200);
    });

    test('旧版（v1）备份缺少新字段时按默认值读出，不报错', () {
      const legacy = '{"app":"驰马时记","format":"chima-timelog",'
          '"format_version":1,"ledgers":[],"records":['
          '{"id":1,"ledger_id":1,"pay_type":0,"start_time":1762900000000,'
          '"end_time":1762930000000,"duration_minutes":480,"rate":25,'
          '"amount":200,"created_at":1762900000000}]}';
      final parsed = BackupService.parseBackupJson(legacy);
      expect(parsed.records.single.breakMinutes, 0);
      expect(parsed.records.single.settlementId, isNull);
      expect(parsed.settlements, isEmpty);
    });
  });
}

/// 测试用的种子色样本（避免直接依赖 services 层）
class AppSettingsSeed {
  static const sample = [
    Color(0xFF1E88E5),
    Color(0xFF2E9E57),
    Color(0xFFEF6C00),
  ];
}

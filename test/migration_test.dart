import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jigongshi/database/database_helper.dart';
import 'package:jigongshi/models/settlement.dart';

/// 真实 SQLite 文件上的迁移测试：
/// 手工按 v1 / v2 建库 → 交给 DatabaseHelper 打开（触发 onUpgrade）→ 校验数据。
/// 这条链路是「老用户升级」的核心风险点，必须自动化跑，不能靠肉眼看。
void main() {
  late Directory tmpDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('chima-migration-');
    dbPath = p.join(tmpDir.path, 'jigongshi.db');
    DatabaseHelper.dbPathOverride = dbPath;
    await DatabaseHelper.instance.close();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.dbPathOverride = null;
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {
      // 清理失败不影响测试结论
    }
  });

  // ============ v1 / v2 建库脚本 ============
  Future<void> createLegacyDb(int version) async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE ledgers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              pay_type INTEGER NOT NULL DEFAULT 0,
              hourly_rate REAL NOT NULL DEFAULT 0,
              daily_rate REAL NOT NULL DEFAULT 0,
              piece_rate REAL NOT NULL DEFAULT 0,
              is_current INTEGER NOT NULL DEFAULT 0,
              color_index INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
          // v2 才有加班/补贴/工种
          final v2Extra = version >= 2
              ? '''
              overtime_minutes INTEGER NOT NULL DEFAULT 0,
              overtime_rate REAL NOT NULL DEFAULT 0,
              subsidy REAL NOT NULL DEFAULT 0,
              job_type TEXT NOT NULL DEFAULT '',
              '''
              : '';
          await db.execute('''
            CREATE TABLE work_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ledger_id INTEGER NOT NULL,
              pay_type INTEGER NOT NULL DEFAULT 0,
              start_time INTEGER NOT NULL,
              end_time INTEGER NOT NULL,
              duration_minutes INTEGER NOT NULL DEFAULT 0,
              piece_count INTEGER NOT NULL DEFAULT 0,
              rate REAL NOT NULL DEFAULT 0,
              $v2Extra
              amount REAL NOT NULL DEFAULT 0,
              note TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    await db.insert('ledgers', {
      'id': 1,
      'name': '张三工地',
      'pay_type': 0,
      'hourly_rate': 25.5,
      'daily_rate': 300.0,
      'piece_rate': 2.0,
      'is_current': 1,
      'color_index': 0,
      'created_at': '2026-11-01T08:00:00.000',
    });
    await db.close();
  }

  Future<int> insertLegacyRecord(
    Map<String, dynamic> values,
  ) async {
    final db = await databaseFactory.openDatabase(dbPath);
    final id = await db.insert('work_records', values);
    await db.close();
    return id;
  }

  group('v2 → v3 迁移', () {
    test('补列建表、日薪 09:00 归零、金额与工时一字不改', () async {
      await createLegacyDb(2);

      // 日薪记录：v2 写的是虚构的 09:00
      final dailyStart = DateTime(2026, 11, 10, 9);
      final dailyId = await insertLegacyRecord({
        'ledger_id': 1,
        'pay_type': 1,
        'start_time': dailyStart.millisecondsSinceEpoch,
        'end_time': dailyStart.millisecondsSinceEpoch,
        'duration_minutes': 0,
        'piece_count': 2,
        'rate': 300.0,
        'overtime_minutes': 0,
        'overtime_rate': 0.0,
        'subsidy': 0.0,
        'job_type': '搬运',
        'amount': 600.0,
        'note': '',
        'created_at': dailyStart.millisecondsSinceEpoch,
      });

      // 时薪夜班：22:00 → 次日 06:00
      final hourlyStart = DateTime(2026, 11, 17, 22);
      final hourlyEnd = DateTime(2026, 11, 18, 6);
      final hourlyId = await insertLegacyRecord({
        'ledger_id': 1,
        'pay_type': 0,
        'start_time': hourlyStart.millisecondsSinceEpoch,
        'end_time': hourlyEnd.millisecondsSinceEpoch,
        'duration_minutes': 480,
        'piece_count': 0,
        'rate': 25.5,
        'overtime_minutes': 30,
        'overtime_rate': 38.0,
        'subsidy': 20.0,
        'job_type': '夜班搬运',
        'amount': 243.0,
        'note': '含餐补',
        'created_at': hourlyStart.millisecondsSinceEpoch,
      });

      // 时薪早班：09:00 是真实上班时间，迁移不能把它也归零
      final morningStart = DateTime(2026, 11, 12, 9);
      final morningId = await insertLegacyRecord({
        'ledger_id': 1,
        'pay_type': 0,
        'start_time': morningStart.millisecondsSinceEpoch,
        'end_time': morningStart.add(const Duration(hours: 8)).millisecondsSinceEpoch,
        'duration_minutes': 480,
        'piece_count': 0,
        'rate': 30.0,
        'overtime_minutes': 0,
        'overtime_rate': 0.0,
        'subsidy': 0.0,
        'job_type': '',
        'amount': 240.0,
        'note': '',
        'created_at': morningStart.millisecondsSinceEpoch,
      });

      // 触发迁移
      final db = await DatabaseHelper.instance.database;

      // 1) 列与表都补上了
      final cols = (await db.rawQuery('PRAGMA table_info(work_records)'))
          .map((c) => c['name'])
          .toSet();
      expect(cols, contains('break_minutes'));
      expect(cols, contains('settlement_id'));
      final tables = (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((t) => t['name'])
          .toSet();
      expect(tables, contains('settlements'));

      // 2) 日薪记录挪到当天 00:00，其余字段不动
      final daily = (await DatabaseHelper.instance.getAllRecords())
          .firstWhere((r) => r.id == dailyId);
      expect(daily.startTime, DateTime(2026, 11, 10));
      expect(daily.endTime, DateTime(2026, 11, 10));
      expect(daily.pieceCount, 2);
      expect(daily.amount, 600.0);
      expect(daily.jobType, '搬运');
      expect(daily.breakMinutes, 0);
      expect(daily.settlementId, isNull);

      // 3) 时薪记录原样保留（含加班/补贴/备注）
      final hourly = (await DatabaseHelper.instance.getAllRecords())
          .firstWhere((r) => r.id == hourlyId);
      expect(hourly.startTime, hourlyStart);
      expect(hourly.endTime, hourlyEnd);
      expect(hourly.durationMinutes, 480);
      expect(hourly.overtimeMinutes, 30);
      expect(hourly.overtimeRate, 38.0);
      expect(hourly.subsidy, 20.0);
      expect(hourly.amount, 243.0);
      expect(hourly.note, '含餐补');

      // 4) 时薪记录的 09:00 是真实上班时间，必须原样保留
      final morning = (await DatabaseHelper.instance.getAllRecords())
          .firstWhere((r) => r.id == morningId);
      expect(morning.startTime, morningStart);
      expect(morning.startTime.hour, 9);
      expect(morning.amount, 240.0);
    });

    test('迁移后能正常生成/撤销结算单', () async {
      await createLegacyDb(2);
      final start = DateTime(2026, 11, 5, 9);
      final id = await insertLegacyRecord({
        'ledger_id': 1,
        'pay_type': 0,
        'start_time': start.millisecondsSinceEpoch,
        'end_time': start.add(const Duration(hours: 8)).millisecondsSinceEpoch,
        'duration_minutes': 480,
        'piece_count': 0,
        'rate': 25.0,
        'overtime_minutes': 0,
        'overtime_rate': 0.0,
        'subsidy': 0.0,
        'job_type': '',
        'amount': 200.0,
        'note': '',
        'created_at': start.millisecondsSinceEpoch,
      });

      final db = await DatabaseHelper.instance.database;
      final settlementId = await DatabaseHelper.instance.createSettlement(
        settlement: Settlement(
          ledgerId: 1,
          periodStart: DateTime(2026, 11, 1),
          periodEnd: DateTime(2026, 12, 1),
          amount: 200,
          recordCount: 1,
          createdAt: DateTime(2026, 11, 30).millisecondsSinceEpoch,
        ),
        recordIds: [id],
      );

      final settled = await DatabaseHelper.instance.getRecordsBySettlement(
        settlementId,
      );
      expect(settled.length, 1);
      expect(settled.single.settlementId, settlementId);
      expect((await DatabaseHelper.instance.getSettlements()).length, 1);

      await DatabaseHelper.instance.revertSettlement(settlementId);
      expect((await DatabaseHelper.instance.getSettlements()), isEmpty);
      final rows = await db.query('work_records', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['settlement_id'], isNull);
    });
  });

  group('v1 → v3 迁移', () {
    test('一次性补齐 v2 与 v3 的所有列，旧记录不丢', () async {
      await createLegacyDb(1);
      final start = DateTime(2026, 10, 20, 9);
      final id = await insertLegacyRecord({
        'ledger_id': 1,
        'pay_type': 0,
        'start_time': start.millisecondsSinceEpoch,
        'end_time': start.add(const Duration(hours: 9)).millisecondsSinceEpoch,
        'duration_minutes': 540,
        'piece_count': 0,
        'rate': 20.0,
        'amount': 180.0,
        'note': 'v1 老数据',
        'created_at': start.millisecondsSinceEpoch,
      });

      final db = await DatabaseHelper.instance.database;
      final cols = (await db.rawQuery('PRAGMA table_info(work_records)'))
          .map((c) => c['name'])
          .toSet();
      for (final c in [
        'overtime_minutes',
        'overtime_rate',
        'subsidy',
        'job_type',
        'break_minutes',
        'settlement_id',
      ]) {
        expect(cols, contains(c), reason: '缺列 $c');
      }

      final r = (await DatabaseHelper.instance.getAllRecords()).single;
      expect(r.id, id);
      expect(r.durationMinutes, 540);
      expect(r.rate, 20.0);
      expect(r.amount, 180.0);
      expect(r.note, 'v1 老数据');
      expect(r.overtimeMinutes, 0);
      expect(r.subsidy, 0.0);
      expect(r.jobType, '');
    });
  });

  test('全新安装：直接建出 v3 结构并能读写', () async {
    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 3);
    final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((t) => t['name'])
        .toSet();
    expect(tables.containsAll(['ledgers', 'work_records', 'settlements']), isTrue);
    expect(await DatabaseHelper.instance.getLedgers(), isEmpty);
    expect(await DatabaseHelper.instance.getAllRecords(), isEmpty);
  });
}

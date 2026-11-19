import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ledger.dart';
import '../models/settlement.dart';
import '../models/work_record.dart';

/// 本地数据库帮助类：负责建库、建表、增删改查。
/// 数据只存在本机（应用私有目录），不联网、不上传。
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  /// v1 初版；v2 补加班/补贴/工种；v3 补休息扣除 + 结算单
  static const int _version = 3;

  /// 仅供测试：指定数据库文件路径，避免用到手机上的真实库
  @visibleForTesting
  static String? dbPathOverride;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  /// 关闭连接（测试里换库/复跑迁移时需要）
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _init() async {
    final path = dbPathOverride ?? join(await getDatabasesPath(), 'jigongshi.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static const String _createLedgers = '''
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
    ''';

  static const String _createWorkRecords = '''
      CREATE TABLE work_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        pay_type INTEGER NOT NULL DEFAULT 0,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 0,
        piece_count INTEGER NOT NULL DEFAULT 0,
        rate REAL NOT NULL DEFAULT 0,
        overtime_minutes INTEGER NOT NULL DEFAULT 0,
        overtime_rate REAL NOT NULL DEFAULT 0,
        subsidy REAL NOT NULL DEFAULT 0,
        job_type TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL DEFAULT 0,
        note TEXT,
        break_minutes INTEGER NOT NULL DEFAULT 0,
        settlement_id INTEGER,
        created_at INTEGER NOT NULL
      )
    ''';

  static const String _createSettlements = '''
      CREATE TABLE IF NOT EXISTS settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        period_start INTEGER NOT NULL,
        period_end INTEGER NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        record_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''';

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createLedgers);
    await db.execute(_createWorkRecords);
    await db.execute(_createSettlements);
  }

  /// 版本升级：只做加列/加表，旧数据原样保留，不重算任何金额。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = await db.rawQuery('PRAGMA table_info(work_records)');
      final names = cols.map((c) => c['name']).toSet();
      Future<void> addIfMissing(String name, String sql) async {
        if (!names.contains(name)) await db.execute(sql);
      }

      await addIfMissing('overtime_minutes',
          'ALTER TABLE work_records ADD COLUMN overtime_minutes INTEGER NOT NULL DEFAULT 0');
      await addIfMissing('overtime_rate',
          'ALTER TABLE work_records ADD COLUMN overtime_rate REAL NOT NULL DEFAULT 0');
      await addIfMissing('subsidy',
          'ALTER TABLE work_records ADD COLUMN subsidy REAL NOT NULL DEFAULT 0');
      await addIfMissing('job_type',
          "ALTER TABLE work_records ADD COLUMN job_type TEXT NOT NULL DEFAULT ''");
    }

    if (oldVersion < 3) {
      final cols = await db.rawQuery('PRAGMA table_info(work_records)');
      final names = cols.map((c) => c['name']).toSet();
      if (!names.contains('break_minutes')) {
        await db.execute(
            'ALTER TABLE work_records ADD COLUMN break_minutes INTEGER NOT NULL DEFAULT 0');
      }
      if (!names.contains('settlement_id')) {
        await db.execute(
            'ALTER TABLE work_records ADD COLUMN settlement_id INTEGER');
      }
      await db.execute(_createSettlements);
      await _normalizeDateOnlyTimes(db);
    }
  }

  /// v3 之前，日薪/计件记录会写一个凭空生成的 09:00 上班时间。
  /// 这类记录本来就没有「几点上班」的概念，统一归到当天 00:00，
  /// 避免后续日历视图把 09:00 当成真实上班时刻展示。
  /// 只处理「时间恰好是 09:00」的记录，不碰任何手填时刻。
  Future<void> _normalizeDateOnlyTimes(Database db) async {
    final rows = await db.query(
      'work_records',
      columns: ['id', 'start_time', 'end_time'],
      where: 'pay_type != 0',
    );
    for (final row in rows) {
      final start =
          DateTime.fromMillisecondsSinceEpoch((row['start_time'] as int?) ?? 0);
      if (start.hour != 9 || start.minute != 0) continue;
      final end =
          DateTime.fromMillisecondsSinceEpoch((row['end_time'] as int?) ?? 0);
      final startMidnight = DateTime(start.year, start.month, start.day);
      final endMidnight = DateTime(end.year, end.month, end.day);
      await db.update(
        'work_records',
        {
          'start_time': startMidnight.millisecondsSinceEpoch,
          'end_time': endMidnight.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  // ============ 雇主账本 ============
  Future<int> insertLedger(Ledger ledger) async {
    final db = await database;
    return db.insert('ledgers', ledger.toMap());
  }

  Future<List<Ledger>> getLedgers() async {
    final db = await database;
    final list = await db.query('ledgers', orderBy: 'is_current DESC, id ASC');
    return list.map((e) => Ledger.fromMap(e)).toList();
  }

  Future<void> updateLedger(Ledger ledger) async {
    final db = await database;
    await db.update('ledgers', ledger.toMap(),
        where: 'id = ?', whereArgs: [ledger.id]);
  }

  Future<void> deleteLedger(int id) async {
    final db = await database;
    await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
    await db.delete('work_records', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('settlements', where: 'ledger_id = ?', whereArgs: [id]);
  }

  Future<void> setCurrentLedger(int id) async {
    final db = await database;
    await db.update('ledgers', {'is_current': 0});
    await db.update('ledgers', {'is_current': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ============ 工时记账记录 ============
  Future<int> insertRecord(WorkRecord r) async {
    final db = await database;
    return db.insert('work_records', r.toMap());
  }

  Future<void> updateRecord(WorkRecord r) async {
    final db = await database;
    await db.update('work_records', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete('work_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkRecord>> getRecordsByLedger(int ledgerId) async {
    final db = await database;
    final list = await db.query(
      'work_records',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'start_time DESC',
    );
    return list.map((e) => WorkRecord.fromMap(e)).toList();
  }

  Future<List<WorkRecord>> getAllRecords() async {
    final db = await database;
    final list = await db.query('work_records', orderBy: 'start_time DESC');
    return list.map((e) => WorkRecord.fromMap(e)).toList();
  }

  /// 取最近一笔记录（用于「复制上次」快速记账）
  Future<WorkRecord?> getLatestRecord() async {
    final db = await database;
    final list = await db.query('work_records', orderBy: 'start_time DESC', limit: 1);
    if (list.isEmpty) return null;
    return WorkRecord.fromMap(list.first);
  }

  // ============ 结算单 ============
  Future<List<Settlement>> getSettlements() async {
    final db = await database;
    final list =
        await db.query('settlements', orderBy: 'created_at DESC, id DESC');
    return list.map((e) => Settlement.fromMap(e)).toList();
  }

  Future<List<WorkRecord>> getRecordsBySettlement(int settlementId) async {
    final db = await database;
    final list = await db.query(
      'work_records',
      where: 'settlement_id = ?',
      whereArgs: [settlementId],
      orderBy: 'start_time ASC',
    );
    return list.map((e) => WorkRecord.fromMap(e)).toList();
  }

  /// 生成结算单并把选中的记录挂到它下面，整体一个事务。
  Future<int> createSettlement({
    required Settlement settlement,
    required List<int> recordIds,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('settlements', settlement.toMap());
      for (final rid in recordIds) {
        await txn.update(
          'work_records',
          {'settlement_id': id},
          where: 'id = ?',
          whereArgs: [rid],
        );
      }
      return id;
    });
  }

  /// 撤销结算：记录回到未结算状态，结算单删除。
  Future<void> revertSettlement(int settlementId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'work_records',
        {'settlement_id': null},
        where: 'settlement_id = ?',
        whereArgs: [settlementId],
      );
      await txn.delete('settlements', where: 'id = ?', whereArgs: [settlementId]);
    });
  }
}

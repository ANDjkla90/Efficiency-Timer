import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../models/ledger.dart';
import '../models/settlement.dart';
import '../models/work_record.dart';

/// 备份文件解析后的一批数据。
class BackupPayload {
  final List<Ledger> ledgers;
  final List<WorkRecord> records;
  final List<Settlement> settlements;

  const BackupPayload({
    required this.ledgers,
    required this.records,
    this.settlements = const [],
  });
}

/// 备份服务：把本机数据导出成 JSON 文件，或从 JSON 文件恢复。
/// 全程使用系统文件选择器（SAF），不需要申请任何存储权限，也不联网。
class BackupService {
  /// 备份文件标识，导入时用于判断是不是本 App 的文件
  static const String appTag = '驰马时记';
  static const String formatTag = 'chima-timelog';

  /// v1：账本 + 记录；v2：增加结算单、休息扣除。
  /// 导入时只校验结构，不因版本号更大就拒绝，缺的字段按默认值补齐。
  static const int formatVersion = 2;

  /// 生成备份 JSON。与文件选择器解耦，便于测试与将来「导出到指定路径」。
  static String buildBackupJson({
    required List<Ledger> ledgers,
    required List<WorkRecord> records,
    List<Settlement> settlements = const [],
    DateTime? now,
  }) {
    final data = {
      'app': appTag,
      'format': formatTag,
      'format_version': formatVersion,
      'export_time': (now ?? DateTime.now()).toIso8601String(),
      'ledgers': ledgers.map((e) => e.toMap()).toList(),
      'records': records.map((e) => e.toMap()).toList(),
      'settlements': settlements.map((e) => e.toMap()).toList(),
    };
    return JsonEncoder.withIndent('  ').convert(data);
  }

  /// 解析备份 JSON。格式不对时抛 [FormatException]，避免把坏文件写进数据库。
  static BackupPayload parseBackupJson(String content) {
    final dynamic decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确：顶层不是 JSON 对象');
    }
    final map = Map<String, dynamic>.from(decoded);
    final ledgersRaw = map['ledgers'];
    final recordsRaw = map['records'];
    if (ledgersRaw is! List && recordsRaw is! List) {
      throw const FormatException('备份文件格式不正确：缺少 ledgers / records');
    }

    List<Map<String, dynamic>> asMapList(dynamic raw, String key) {
      if (raw == null) return const [];
      if (raw is! List) {
        throw FormatException('备份文件格式不正确：$key 不是数组');
      }
      return raw.map<Map<String, dynamic>>((e) {
        if (e is! Map) {
          throw FormatException('备份文件格式不正确：$key 中存在非法条目');
        }
        return Map<String, dynamic>.from(e);
      }).toList();
    }

    return BackupPayload(
      ledgers: asMapList(ledgersRaw, 'ledgers')
          .map(Ledger.fromMap)
          .toList(growable: false),
      records: asMapList(recordsRaw, 'records')
          .map(WorkRecord.fromMap)
          .toList(growable: false),
      settlements: asMapList(map['settlements'], 'settlements')
          .map(Settlement.fromMap)
          .toList(growable: false),
    );
  }

  /// 导出：把所有账本和工时记录打包成 JSON，让用户选择保存位置。
  /// 返回保存结果描述；用户取消时返回 null。
  static Future<String?> exportData({
    String dialogTitle = '导出数据备份',
    String fileNamePrefix = '驰马时记备份',
  }) async {
    final db = DatabaseHelper.instance;
    final ledgers = await db.getLedgers();
    final records = await db.getAllRecords();
    final settlements = await db.getSettlements();

    final json = buildBackupJson(
      ledgers: ledgers,
      records: records,
      settlements: settlements,
    );
    final bytes = Uint8List.fromList(utf8.encode(json));

    // 弹出系统保存对话框，并直接把数据写入用户选定的位置（免存储权限）
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: '${fileNamePrefix}_${_dateStr()}.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (uri == null) return null; // 用户取消
    return uri.toString();
  }

  /// 导入：让用户选择之前导出的 JSON 文件，覆盖恢复数据。
  /// 返回恢复的账本数量；用户取消时返回 null。
  static Future<int?> importData({String dialogTitle = '选择备份文件'}) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return null; // 用户取消
    final file = files.first;
    final path = file.path;
    if (path == null) {
      throw const FormatException('无法读取所选文件');
    }
    final content = await File(path).readAsString();
    return restorePayload(parseBackupJson(content));
  }

  /// 恢复：清空现有数据，写入备份数据，返回恢复的账本数。
  /// 整套操作在一个事务里，中途失败会整体回滚，不会留下半份数据。
  static Future<int> restorePayload(BackupPayload payload) async {
    final database = await DatabaseHelper.instance.database;
    await database.transaction((txn) async {
      await txn.delete('work_records');
      await txn.delete('settlements');
      await txn.delete('ledgers');
      for (final l in payload.ledgers) {
        await txn.insert('ledgers', l.toMap());
      }
      for (final s in payload.settlements) {
        await txn.insert('settlements', s.toMap());
      }
      for (final r in payload.records) {
        await txn.insert('work_records', r.toMap());
      }
    });
    return payload.ledgers.length;
  }

  static String _dateStr() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

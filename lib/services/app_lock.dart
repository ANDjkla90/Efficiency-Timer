import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地应用锁：4/6 位 PIN，校验值（盐 + SHA-256）只存在本机偏好里。
///
/// 定位说明（不要夸大）：它挡的是「手机递给别人、别人点开 App」这种场景，
/// 不加密数据库本身。设备被 root / 拆机取证仍然能读到账目，
/// 真正的底线仍是「不联网、零权限、数据只在本机」。
///
/// 防暴力破解：连续输错 5 次后开始递增延时（1s / 2s / 4s / 8s / 16s，上限 30s），
/// 失败次数与解锁时间点都落盘，杀进程重启也清不掉。4 位 PIN 只有一万种组合，
/// 没有这道闸门，脚本几分钟就能试完。
class AppLock extends ChangeNotifier {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const int length4 = 4;
  static const int length6 = 6;

  /// 输错到这个次数后开始延时
  static const int throttleAfter = 5;

  /// 单次延时上限（秒）
  static const int maxThrottleSeconds = 30;

  static const _kEnabled = 'app_lock_enabled';
  static const _kPinLength = 'app_lock_pin_length';
  static const _kSalt = 'app_lock_salt';
  static const _kHash = 'app_lock_hash';
  static const _kFailedAttempts = 'app_lock_failed_attempts';
  static const _kLockedUntil = 'app_lock_locked_until';

  bool _enabled = false;
  bool _locked = false;
  bool _ready = false;
  int _pinLength = length4;
  String _salt = '';
  String _hash = '';
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  bool get enabled => _enabled;
  bool get locked => _locked;
  bool get ready => _ready;
  int get pinLength => _pinLength;
  int get failedAttempts => _failedAttempts;

  /// 纯函数：连续失败 [failedAttempts] 次后要等多久才能再试。
  /// 前 4 次不延时，第 5 次 1 秒，之后翻倍，封顶 30 秒。
  static Duration throttleFor(int failedAttempts) {
    if (failedAttempts < throttleAfter) return Duration.zero;
    final step = failedAttempts - throttleAfter;
    final seconds = 1 << (step > 5 ? 5 : step);
    return Duration(
        seconds: seconds > maxThrottleSeconds ? maxThrottleSeconds : seconds);
  }

  /// 还需要等多久（已过期返回 0）
  Duration get remainingLockout {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// 冷却中：此时不接受输入，也不做校验
  bool get throttled => remainingLockout > Duration.zero;

  /// 冷却剩余秒数（向上取整，0 表示可以输入）
  int get lockoutSeconds {
    final ms = remainingLockout.inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;
    _pinLength = prefs.getInt(_kPinLength) ?? length4;
    _salt = prefs.getString(_kSalt) ?? '';
    _hash = prefs.getString(_kHash) ?? '';
    _failedAttempts = prefs.getInt(_kFailedAttempts) ?? 0;
    final untilMs = prefs.getInt(_kLockedUntil);
    if (untilMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      _lockedUntil = until.isAfter(DateTime.now()) ? until : null;
    }
    // 配置残缺（比如只写了一半就崩了）按「未开启」处理，避免把自己锁在门外
    if (_enabled && (_salt.isEmpty || _hash.isEmpty)) {
      _enabled = false;
    }
    _locked = _enabled;
    _ready = true;
    notifyListeners();
  }

  /// 纯函数：盐 + PIN → 校验值。抽出来是为了单元测试能直接覆盖。
  static String hashPin(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt|$pin|chima-timelog')).toString();

  /// 只允许纯数字，长度必须是 4 或 6
  static bool isValidPin(String pin, {int? expectedLength}) {
    if (!RegExp(r'^\d+$').hasMatch(pin)) return false;
    final len = pin.length;
    if (len != length4 && len != length6) return false;
    if (expectedLength != null && len != expectedLength) return false;
    return true;
  }

  static String newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// 设置/修改 PIN：成功后立即解除锁定态，并清空失败计数。
  Future<void> setPin(String pin, {int length = length4}) async {
    final salt = newSalt();
    final hash = hashPin(salt, pin);
    _salt = salt;
    _hash = hash;
    _pinLength = length;
    _enabled = true;
    _locked = false;
    _ready = true;
    _failedAttempts = 0;
    _lockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    await prefs.setInt(_kPinLength, length);
    await prefs.setString(_kSalt, salt);
    await prefs.setString(_kHash, hash);
    await _saveAttempts(prefs);
    notifyListeners();
  }

  /// 校验 PIN。失败会累计次数并按 [throttleFor] 设置冷却时间。
  /// 冷却期内直接返回 false，调用方应先用 [throttled] 拦住输入。
  Future<bool> verify(String pin) async {
    if (!_enabled || _salt.isEmpty) return false;
    if (throttled) return false;
    final ok = hashPin(_salt, pin) == _hash;
    if (ok) {
      if (_failedAttempts != 0 || _lockedUntil != null) {
        _failedAttempts = 0;
        _lockedUntil = null;
        await _saveAttempts();
      }
      return true;
    }
    _failedAttempts++;
    final delay = throttleFor(_failedAttempts);
    _lockedUntil = delay == Duration.zero ? null : DateTime.now().add(delay);
    await _saveAttempts();
    return false;
  }

  /// 关闭应用锁：调用方必须先 verify 通过。
  Future<void> disable() async {
    _enabled = false;
    _locked = false;
    _salt = '';
    _hash = '';
    _failedAttempts = 0;
    _lockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await prefs.remove(_kSalt);
    await prefs.remove(_kHash);
    await prefs.remove(_kFailedAttempts);
    await prefs.remove(_kLockedUntil);
    notifyListeners();
  }

  Future<void> _saveAttempts([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    await prefs.setInt(_kFailedAttempts, _failedAttempts);
    final until = _lockedUntil;
    if (until == null) {
      await prefs.remove(_kLockedUntil);
    } else {
      await prefs.setInt(_kLockedUntil, until.millisecondsSinceEpoch);
    }
  }

  void lock() {
    if (!_enabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// 退到后台超过这个秒数，回来就要重新解锁。
  /// 留 30 秒是为了不打断「选备份文件」这类系统弹窗——一进一出就上锁会很烦。
  static const int backgroundLockSeconds = 30;

  DateTime? _pausedAt;

  /// 退到后台再回来：只有离开够久才重新上锁
  void onAppPaused() {
    _pausedAt = DateTime.now();
  }

  void onAppResumed() {
    if (!_enabled || _pausedAt == null) return;
    final away = DateTime.now().difference(_pausedAt!).inSeconds;
    _pausedAt = null;
    if (away >= backgroundLockSeconds) lock();
  }
}

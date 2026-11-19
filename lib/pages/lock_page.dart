import 'dart:async';

import 'package:flutter/material.dart';
import '../services/app_lock.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

/// 解锁页：应用锁开启时，启动或回到前台后先看到它。
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  int _reset = 0;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 上次输错触发的冷却可能还没结束（甚至跨了重启），进来就先把倒计时跑起来
    if (AppLock.instance.throttled) _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!AppLock.instance.throttled) {
        t.cancel();
        _timer = null;
        if (mounted) setState(() => _error = null);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _submit(String pin, L10n s) async {
    if (AppLock.instance.throttled) return;
    final ok = await AppLock.instance.verify(pin);
    if (!mounted) return;
    if (ok) {
      AppLock.instance.unlock();
      return;
    }
    final left = AppLock.instance.lockoutSeconds;
    setState(() {
      _error = left > 0 ? s.pinThrottled(left) : s.pinWrong;
      _reset++;
    });
    if (left > 0) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final lock = AppLock.instance;
    // 冷却中：文案换成倒计时，键盘置灰不可点
    final error = lock.throttled ? s.pinThrottled(lock.lockoutSeconds) : _error;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(Icons.lock_outline, size: 40, color: Tones.primary(context)),
            const SizedBox(height: 10),
            Text(s.appTitle,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.privacyLine,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: PinPad(
                    length: lock.pinLength,
                    title: s.pinUnlockTitle,
                    errorText: error,
                    resetToken: _reset,
                    enabled: !lock.throttled,
                    onCompleted: (pin) => _submit(pin, s),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(s.pinForgot),
                  content: Text(s.pinForgotDesc),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(s.pinCancel),
                    ),
                  ],
                ),
              ),
              child: Text(s.pinForgot,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

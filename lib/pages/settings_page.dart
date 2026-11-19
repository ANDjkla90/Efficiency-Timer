import 'package:flutter/material.dart';
import '../services/app_lock.dart';
import '../services/app_settings.dart';
import '../services/backup_service.dart';
import '../services/data_notifier.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';
import 'currency_page.dart';
import 'ledger_manage_page.dart';
import 'privacy_page.dart';
import 'settlement_page.dart';

/// 设置页：外观 / 应用锁 / 雇主与结算 / 备份 / 隐私 / 关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    AppLock.instance.addListener(_onLockChanged);
  }

  @override
  void dispose() {
    AppLock.instance.removeListener(_onLockChanged);
    super.dispose();
  }

  void _onLockChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export(BuildContext context, L10n s) async {
    String? path;
    try {
      path = await BackupService.exportData(
        dialogTitle: s.exportBackup,
        fileNamePrefix: s.backupFileNamePrefix,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.exportFailed)),
      );
      return;
    }
    if (!context.mounted) return;
    if (path == null) return; // 用户取消
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.exportedTo(path))),
    );
  }

  Future<void> _import(BuildContext context, L10n s) async {
    // 导入会覆盖现有数据，先确认
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importTitle),
        content: Text(s.importDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    int? count;
    String? error;
    try {
      count = await BackupService.importData(dialogTitle: s.importDialogTitle);
    } on FormatException {
      // 文件损坏 / 不是本应用的备份：解析阶段就抛错，数据库未被改动
      error = s.importFailed;
    } catch (_) {
      // 读取失败（文件被移动、权限受限等）
      error = s.importReadFailed;
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (count == null) return; // 用户取消
    DataNotifier.instance.notify();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.restoredCount(count))),
    );
  }

  /// 语言选择弹窗：跟随系统 / 简体中文 / English
  Future<void> _pickLanguage(BuildContext context, L10n s) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.language),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radioTile(ctx, s.followSystem, AppSettings.localeFollowSystem,
                settings.localeMode),
            _radioTile(ctx, s.chinese, AppSettings.localeChinese,
                settings.localeMode),
            _radioTile(ctx, s.english, AppSettings.localeEnglish,
                settings.localeMode),
          ],
        ),
      ),
    );
    if (picked != null) await settings.setLocaleMode(picked);
  }

  Widget _radioTile(BuildContext ctx, String label, int value, int current) =>
      RadioListTile<int>(
        value: value,
        groupValue: current,
        title: Text(label),
        onChanged: (v) => Navigator.pop(ctx, v),
      );

  /// 主题配色选择弹窗：5 套主色，带色块预览
  Future<void> _pickColor(BuildContext context, L10n s) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.themeColor),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(AppSettings.seedColors.length, (i) {
            final color = AppSettings.seedColors[i];
            return RadioListTile<int>(
              value: i,
              groupValue: settings.colorIndex,
              title: Text(s.themeColorNames[i]),
              secondary: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: settings.colorIndex == i
                        ? Theme.of(ctx).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (v) => Navigator.pop(ctx, v),
            );
          }),
        ),
      ),
    );
    if (picked != null) await settings.setColorIndex(picked);
  }

  /// 深色模式选择弹窗：跟随系统 / 浅色 / 深色
  Future<void> _pickThemeMode(BuildContext context, L10n s) async {
    final settings = AppSettings.instance;
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.darkMode),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              title: Text(s.followSystem),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              title: Text(s.lightMode),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              title: Text(s.darkModeOption),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await settings.setThemeMode(picked);
  }

  /// 当前语言/模式/配色的右侧摘要文字
  String _languageSummary(L10n s) {
    switch (AppSettings.instance.localeMode) {
      case AppSettings.localeChinese:
        return s.chinese;
      case AppSettings.localeEnglish:
        return s.english;
      default:
        return s.followSystem;
    }
  }

  String _themeModeSummary(L10n s) {
    switch (AppSettings.instance.themeMode) {
      case ThemeMode.light:
        return s.lightMode;
      case ThemeMode.dark:
        return s.darkModeOption;
      default:
        return s.followSystem;
    }
  }

  // ============ 应用锁 ============
  Future<int?> _pickPinLength(L10n s) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.pinLengthTitle),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.pin4),
              onTap: () => Navigator.pop(ctx, AppLock.length4),
            ),
            ListTile(
              title: Text(s.pin6),
              onTap: () => Navigator.pop(ctx, AppLock.length6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableLock(L10n s) async {
    final len = await _pickPinLength(s);
    if (len == null || !mounted) return;
    final first = await showPinDialog(
      context,
      title: s.pinSetTitle,
      length: len,
      subtitle: s.pinHintSet,
    );
    if (first == null || !mounted) return;
    final second = await showPinDialog(
      context,
      title: s.pinConfirmTitle,
      length: len,
    );
    if (second == null) return;
    if (first != second) {
      _toast(s.pinMismatch);
      return;
    }
    await AppLock.instance.setPin(first, length: len);
    _toast(s.appLockEnabled);
  }

  /// 验证当前 PIN，通过返回 true
  Future<bool> _verifyCurrent(L10n s) async {
    final lock = AppLock.instance;
    if (lock.throttled) {
      _toast(s.pinThrottled(lock.lockoutSeconds));
      return false;
    }
    final pin = await showPinDialog(
      context,
      title: s.pinVerifyTitle,
      length: lock.pinLength,
    );
    if (pin == null) return false;
    final ok = await lock.verify(pin);
    if (!ok && mounted) {
      _toast(lock.throttled
          ? s.pinThrottled(lock.lockoutSeconds)
          : s.pinWrong);
    }
    return ok;
  }

  Future<void> _disableLock(L10n s) async {
    if (!await _verifyCurrent(s)) return;
    await AppLock.instance.disable();
    _toast(s.appLockDisabled);
  }

  Future<void> _changePin(L10n s) async {
    if (!await _verifyCurrent(s)) return;
    if (!mounted) return;
    final len = AppLock.instance.pinLength;
    final first = await showPinDialog(
      context,
      title: s.pinSetTitle,
      length: len,
      subtitle: s.pinHintSet,
    );
    if (first == null || !mounted) return;
    final second = await showPinDialog(
      context,
      title: s.pinConfirmTitle,
      length: len,
    );
    if (second == null) return;
    if (first != second) {
      _toast(s.pinMismatch);
      return;
    }
    await AppLock.instance.setPin(first, length: len);
    _toast(s.pinChanged);
  }

  /// 国家/地区与货币摘要：地区名 + 当前生效货币
  String _currencySummary(L10n s) {
    final settings = AppSettings.instance;
    final code = settings.effectiveCountryCode;
    final region = regionByCode(code);
    final regionName = region?.name(s.isZh) ?? s.currencyUnconfigured(code.isEmpty ? '--' : code);
    final c = settings.currency;
    return s.currencyRegionSummary(regionName, c.name(s.isZh), c.symbol);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final primary = Tones.primary(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.me)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ——— 外观设置 ———
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language, color: primary),
                  title: Text(s.language),
                  subtitle: Text(_languageSummary(s)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickLanguage(context, s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: primary),
                  title: Text(s.themeColor),
                  subtitle:
                      Text(s.themeColorNames[AppSettings.instance.colorIndex]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickColor(context, s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.dark_mode_outlined, color: primary),
                  title: Text(s.darkMode),
                  subtitle: Text(_themeModeSummary(s)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickThemeMode(context, s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.attach_money_outlined, color: primary),
                  title: Text(s.currencyRegion),
                  subtitle: Text(_currencySummary(s)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CurrencyPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ——— 安全：应用锁 ——
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.lock_outline, color: primary),
                  title: Text(s.appLock),
                  subtitle: Text(AppLock.instance.enabled
                      ? s.appLockSummaryOn(AppLock.instance.pinLength)
                      : s.appLockSummaryOff),
                  value: AppLock.instance.enabled,
                  onChanged: (v) {
                    if (v) {
                      _enableLock(s);
                    } else {
                      _disableLock(s);
                    }
                  },
                ),
                if (AppLock.instance.enabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.password_outlined, color: primary),
                    title: Text(s.pinChange),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePin(s),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.lock_clock_outlined, color: primary),
                    title: Text(s.lockNow),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AppLock.instance.lock(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ——— 数据与隐私 ———
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.folder_outlined, color: primary),
                  title: Text(s.employerManage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LedgerManagePage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.receipt_long_outlined, color: primary),
                  title: Text(s.settlements),
                  subtitle: Text(s.settlementSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettlementPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.backup_outlined, color: primary),
                  title: Text(s.exportBackup),
                  subtitle: Text(s.exportSub),
                  onTap: () => _export(context, s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.restore, color: primary),
                  title: Text(s.importBackup),
                  subtitle: Text(s.importSub),
                  onTap: () => _import(context, s),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: primary),
                  title: Text(s.privacy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline, color: primary),
                  title: Text(s.about),
                  subtitle: Text(s.aboutSub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              s.privacyLine,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

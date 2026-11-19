import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/currency_config.dart';
import '../l10n/app_strings.dart';
export '../l10n/app_strings.dart'; // 页面通过本文件即可拿到 L10n 类型
export '../config/currency_config.dart'; // 页面可直接拿到货币定义

/// 全局外观设置：语言 / 主题配色 / 深浅模式。
/// 单例 + ChangeNotifier，改动后 notifyListeners 让全 App 重建，并立即落盘。
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const int localeFollowSystem = 0;
  static const int localeChinese = 1;
  static const int localeEnglish = 2;

  /// 国家/地区来源：0=跟随系统地区  1=手动选择
  static const int countryFollowSystem = 0;
  static const int countryManual = 1;

  /// 5 套主题主色，与设置页的选项顺序一致。
  static const List<Color> seedColors = [
    Color(0xFF1E88E5), // 科技蓝
    Color(0xFF2E9E57), // 活力绿
    Color(0xFFEF6C00), // 暖阳橙
    Color(0xFFD32F2F), // 热情红
    Color(0xFF7B1FA2), // 优雅紫
  ];

  int _localeMode = localeFollowSystem;
  ThemeMode _themeMode = ThemeMode.system;
  int _colorIndex = 0;
  // 默认钉在「手动 · 中国」：跟随系统地区是高级选项，需用户显式开启。
  // 避免中国用户把系统语言设成 en-US 后工钱符号无声变成 $。
  int _countryMode = countryManual;
  String _countryCode = 'CN';
  String _defaultCurrencyCode = kDefaultCurrencyCode;

  int get localeMode => _localeMode;
  ThemeMode get themeMode => _themeMode;
  int get colorIndex => _colorIndex;
  Color get seedColor => seedColors[_colorIndex.clamp(0, seedColors.length - 1)];

  int get countryMode => _countryMode;
  String get countryCode => _countryCode;
  String get defaultCurrencyCode => _defaultCurrencyCode;

  /// 当前地区代码：手动选择优先，否则取系统地区（不申请定位权限）。
  String get effectiveCountryCode => _countryMode == countryManual
      ? _countryCode
      : (_systemCountryCode ?? '');

  /// 当前生效货币：地区映射命中则用对应货币，否则用用户设定的默认货币。
  CurrencyDef get currency => currencyForCountry(
        effectiveCountryCode,
        defaultCurrencyCode: _defaultCurrencyCode,
      );

  String? get _systemCountryCode {
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final locales = dispatcher.locales;
      for (final l in locales) {
        final c = l.countryCode;
        if (c != null && c.isNotEmpty) return c.toUpperCase();
      }
      final c = dispatcher.locale.countryCode;
      return (c == null || c.isEmpty) ? null : c.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  /// 实际生效的语言：跟随系统时按系统语言决定，非中即英。
  Locale get locale {
    switch (_localeMode) {
      case localeChinese:
        return const Locale('zh');
      case localeEnglish:
        return const Locale('en');
      default:
        final sys = WidgetsBinding.instance.platformDispatcher.locale;
        return sys.languageCode == 'zh' ? const Locale('zh') : const Locale('en');
    }
  }

  L10n get strings => L10n(locale.languageCode == 'zh');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _localeMode = prefs.getInt(_kLocaleMode) ?? localeFollowSystem;
    _colorIndex = prefs.getInt(_kColorIndex) ?? 0;
    _countryMode = prefs.getInt(_kCountryMode) ?? countryManual;
    _countryCode = prefs.getString(_kCountryCode) ?? 'CN';
    // 旧版本（v2.3）默认「跟随系统」的用户升级后一并钉回 CN，
    // 除非他们重新显式选择跟随系统。
    if (_countryMode == countryFollowSystem && _countryCode.isEmpty) {
      _countryMode = countryManual;
      _countryCode = 'CN';
    }
    _defaultCurrencyCode = prefs.getString(_kDefaultCurrency) ?? kDefaultCurrencyCode;
    switch (prefs.getString(_kThemeMode)) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  static const _kLocaleMode = 'locale_mode';
  static const _kColorIndex = 'theme_color_index';
  static const _kThemeMode = 'theme_mode';
  static const _kCountryMode = 'country_mode';
  static const _kCountryCode = 'country_code';
  static const _kDefaultCurrency = 'default_currency_code';

  Future<void> setLocaleMode(int mode) async {
    if (mode == _localeMode) return;
    _localeMode = mode;
    await _save((p) => p.setInt(_kLocaleMode, mode));
  }

  Future<void> setColorIndex(int index) async {
    if (index == _colorIndex) return;
    _colorIndex = index;
    await _save((p) => p.setInt(_kColorIndex, index));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    await _save((p) => p.setString(_kThemeMode, mode.name));
  }

  /// 切换地区来源：跟随系统 / 手动选择。
  Future<void> setCountryMode(int mode) async {
    if (mode == _countryMode) return;
    _countryMode = mode;
    await _save((p) => p.setInt(_kCountryMode, mode));
  }

  Future<void> setCountryCode(String code) async {
    if (code == _countryCode) return;
    _countryCode = code.toUpperCase();
    await _save((p) => p.setString(_kCountryCode, _countryCode));
  }

  /// 未配置国家/地区时使用的默认货币。
  Future<void> setDefaultCurrencyCode(String code) async {
    if (!kCurrencies.containsKey(code) || code == _defaultCurrencyCode) return;
    _defaultCurrencyCode = code;
    await _save((p) => p.setString(_kDefaultCurrency, code));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences p) write) async {
    final prefs = await SharedPreferences.getInstance();
    await write(prefs);
    notifyListeners();
  }
}

/// 把当前设置注入 widget 树，页面用 stringsOf(context) 读取文案并自动跟随重建。
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppSettings settingsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static L10n stringsOf(BuildContext context) => settingsOf(context).strings;
}

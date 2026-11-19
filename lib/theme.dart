import 'package:flutter/material.dart';

/// 主题工厂：用主色 seed 生成浅色 / 深色两套 ThemeData。
/// 换配色只需换 seedColor，深浅模式由 MaterialApp.themeMode 切换。
ThemeData buildAppTheme({
  required Color seedColor,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final bg = isDark ? const Color(0xFF121316) : const Color(0xFFF5F6F8);
  final card = isDark ? const Color(0xFF1E2024) : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: bg,
      foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
      iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white12 : const Color(0xFFE9ECF1),
      space: 1,
    ),
    dialogTheme: DialogThemeData(backgroundColor: card),
  );
}

/// 顶部强调卡片的渐变色，随主题色变化，深浅模式自动调暗。
List<Color> heroGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return [primary, Color.lerp(primary, Colors.black, 0.28)!];
}

/// 语义色：主色 / 深一档主色 / 浅底 / 浅底上的主色文字。
/// 让原本写死的品牌色改为跟随主题，切换配色时全 App 一致变化。
class Tones {
  static Color primary(BuildContext c) => Theme.of(c).colorScheme.primary;
  static Color onPrimarySoft(BuildContext c) =>
      Theme.of(c).colorScheme.primary.withValues(alpha: 0.14);
  static Color primaryInk(BuildContext c) =>
      Color.lerp(Theme.of(c).colorScheme.primary, Colors.black, 0.12)!;
}

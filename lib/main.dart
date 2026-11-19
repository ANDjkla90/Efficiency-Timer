import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/lock_page.dart';
import 'pages/main_shell.dart';
import 'pages/splash_page.dart';
import 'services/app_lock.dart';
import 'services/app_settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先读取本地保存的语言/主题/配色/应用锁，再启动，避免首帧闪烁
  await AppSettings.instance.init();
  await AppLock.instance.init();
  // 开屏只在首次安装显示一次，日常打开直接进主界面
  final prefs = await SharedPreferences.getInstance();
  final seenSplash = prefs.getBool(_kSeenSplash) ?? false;
  // 竖屏锁定：界面简单，横屏意义不大
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(AppRoot(showSplash: !seenSplash));
}

const String _kSeenSplash = 'has_seen_splash';

class AppRoot extends StatefulWidget {
  final bool showSplash;
  const AppRoot({super.key, this.showSplash = false});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.showSplash;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        AppLock.instance.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        AppLock.instance.onAppResumed();
        break;
      default:
        break;
    }
  }

  Future<void> _onSplashFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenSplash, true);
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    // 设置一变（语言/配色/深浅）或锁定状态一变，整个 MaterialApp 重建
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettings.instance, AppLock.instance]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        final s = settings.strings;
        // 应用锁优先：锁着就不渲染主界面，避免数据在后台被瞥见
        final Widget home;
        if (AppLock.instance.locked) {
          home = const LockPage();
        } else if (_showSplash) {
          home = SplashPage(onFinish: _onSplashFinish);
        } else {
          home = const MainShell();
        }
        return MaterialApp(
          title: s.appTitle,
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAppTheme(
              seedColor: settings.seedColor, brightness: Brightness.light),
          darkTheme: buildAppTheme(
              seedColor: settings.seedColor, brightness: Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) => AppScope(notifier: settings, child: child!),
          home: home,
        );
      },
    );
  }
}

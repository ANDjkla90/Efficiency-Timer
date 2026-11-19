import 'package:flutter/material.dart';
import 'home_page.dart';
import 'record_list_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import '../services/app_settings.dart';

/// 主框架：底部四个导航栏，切换首页 / 账目 / 统计 / 我的。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    RecordListPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: s.tabRecords,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: s.tabStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: s.tabMe,
          ),
        ],
      ),
    );
  }
}

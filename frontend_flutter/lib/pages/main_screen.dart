import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'history/history_page.dart';
import 'home/home_page.dart';

/// 登录后的主框架：底部"首页 / 历史"两个 Tab（原在 main.dart，A-2 时移出）。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      const HomePage(),
      // 历史空状态的"去拍照"切回首页 Tab
      HistoryPage(onGoHome: () => setState(() => _currentIndex = 0)),
    ];
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.cottage_outlined),
            selectedIcon: const Icon(Icons.cottage),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_edu_outlined),
            selectedIcon: const Icon(Icons.history_edu),
            label: l10n.tabHistory,
          ),
        ],
      ),
    );
  }
}

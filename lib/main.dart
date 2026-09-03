import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const StorageOptimizerApp());
}

class StorageOptimizerApp extends StatelessWidget {
  const StorageOptimizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Optimizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _screens = [
    DashboardScreen(),
    RecommendationsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.delete_outline),
      selectedIcon: Icon(Icons.delete),
      label: 'Recommend',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  // A single DefaultTabController owns the only TabController in the app.
  // Previously this widget also created its own controller for the TabBarView,
  // so `DefaultTabController.of(context).animateTo(...)` from a child screen
  // drove a controller no widget was listening to and navigation silently did
  // nothing.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _screens.length,
      child: _NavShell(screens: _screens, navItems: _navItems),
    );
  }
}

class _NavShell extends StatelessWidget {
  final List<Widget> screens;
  final List<NavigationDestination> navItems;

  const _NavShell({required this.screens, required this.navItems});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    return Scaffold(
      body: TabBarView(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
      // Rebuilds the bar whenever the shared controller moves, including when
      // a child screen navigates programmatically.
      bottomNavigationBar: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => NavigationBar(
          selectedIndex: controller.index,
          onDestinationSelected: controller.animateTo,
          destinations: navItems,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 64,
        ),
      ),
    );
  }
}

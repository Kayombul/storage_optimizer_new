import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await _startMediaWatch();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const StorageOptimizerApp());
}

/// Proactive alerts are the point of the app, so the background watcher is on
/// by default. Re-scheduling an already-scheduled worker is a no-op, so this is
/// safe to call on every launch; the user can turn it off in Settings.
Future<void> _startMediaWatch() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('media_watch') ?? true) {
      await StorageService.instance.setMediaWatchEnabled(true);
      await prefs.setBool('media_watch', true);
    }
  } catch (_) {
    // Never let alert scheduling stop the app from starting.
  }
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

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _screens.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The shell owns the one TabController that actually drives the TabBarView,
    // and publishes it so screens can switch tabs. Wrapping this in a
    // DefaultTabController instead would create a *second*, unused controller,
    // and any screen calling DefaultTabController.of(context) would silently
    // animate that one while the visible view never moved.
    return AppTabs(
      controller: _tabController,
      child: _NavShell(
        tabController: _tabController,
        screens: _screens,
        navItems: _navItems,
      ),
    );
  }
}

/// Publishes the shell's TabController so any descendant can switch tabs, e.g.
/// the dashboard's "View Recommendations" button.
class AppTabs extends InheritedWidget {
  final TabController controller;

  const AppTabs({
    super.key,
    required this.controller,
    required super.child,
  });

  static TabController of(BuildContext context) {
    final tabs = context.dependOnInheritedWidgetOfExactType<AppTabs>();
    assert(tabs != null, 'AppTabs.of() called from outside the MainShell');
    return tabs!.controller;
  }

  @override
  bool updateShouldNotify(AppTabs oldWidget) =>
      controller != oldWidget.controller;
}

class _NavShell extends StatelessWidget {
  final TabController tabController;
  final List<Widget> screens;
  final List<NavigationDestination> navItems;

  const _NavShell({
    required this.tabController,
    required this.screens,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabController.index,
        onDestinationSelected: tabController.animateTo,
        destinations: navItems,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 64,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'explorer_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<Tab> _tabs = <Tab>[
    Tab(icon: Icon(Icons.home_outlined)),
    Tab(icon: Icon(Icons.photo_library_outlined)),
    Tab(icon: Icon(Icons.settings_outlined)),
  ];

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    ExplorerPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Text(
          _currentTitle,
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C281D)
            : Theme.of(context).colorScheme.primary,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.white,
              width: 3,
            ),
            insets: const EdgeInsets.symmetric(horizontal: 24),
          ),
          labelColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
    );
  }

  String get _currentTitle {
    switch (_tabController.index) {
      case 0:
        return 'Home';
      case 1:
        return 'Explorer';
      case 2:
        return 'Einstellungen';
      default:
        return 'Prename App';
    }
  }
}

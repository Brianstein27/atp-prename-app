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
    Tab(text: 'Home'),
    Tab(text: 'Explorer'),
    Tab(text: 'Einstellungen'),
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
          "Prename App",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.lightGreen.shade700,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          indicator: UnderlineTabIndicator(
            borderSide: const BorderSide(color: Colors.white, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 24),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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

}

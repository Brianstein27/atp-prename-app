import 'package:flutter/material.dart';

import '../l10n/localization_helper.dart';

import 'explorer_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import '../services/camera_service.dart';
import 'package:provider/provider.dart';
import '../utils/tab_navigation_model.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  TabNavigationModel? _tabNavigationModel;

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
    CameraService.instance.warmUp(background: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newModel = Provider.of<TabNavigationModel>(context);
    if (_tabNavigationModel == newModel) return;
    _tabNavigationModel?.removeListener(_handleExternalTabRequest);
    _tabNavigationModel = newModel;
    _tabNavigationModel?.addListener(_handleExternalTabRequest);
    if (_tabNavigationModel!.index != _tabController.index) {
      _tabNavigationModel!.jumpTo(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _tabNavigationModel?.removeListener(_handleExternalTabRequest);
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
      final navModel = _tabNavigationModel;
      if (navModel != null && navModel.index != _tabController.index) {
        navModel.jumpTo(_tabController.index);
      }
    }
  }

  void _handleExternalTabRequest() {
    final target = _tabNavigationModel?.index ?? 0;
    if (_tabController.index != target) {
      _tabController.animateTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Text(
          _currentTitle(context),
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
                  : Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.7),
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

  String _currentTitle(BuildContext context) {
    switch (_tabController.index) {
      case 0:
        return context.tr(de: 'Home', en: 'Home');
      case 1:
        return context.tr(de: 'Galerie', en: 'Gallery');
      case 2:
        return context.tr(de: 'Einstellungen', en: 'Settings');
      default:
        return context.tr(de: 'Prename App', en: 'Prename App');
    }
  }
}

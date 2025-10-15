import 'package:atp_prename_app/pages/explorer_page.dart';
import 'package:atp_prename_app/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';

// Die Hauptansicht, die zwischen Home (Kamera) und Explorer (Galerie) wechselt.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 0 für HomePage, 1 für ExplorerPage
  int _selectedIndex = 0;

  // Liste der Seiten in der App (State bleibt durch IndexedStack erhalten)
  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    ExplorerPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Schließt den Drawer nach der Auswahl
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Home' : 'Gallerie',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.lightGreen.shade700,
        elevation: 0,
        foregroundColor: Colors.white, // Farbe des Drawer-Icons
      ),

      // Implementierung des Drawers für die Navigation
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.lightGreen.shade700),
              child: const Text(
                'Navigation',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // Home-Link
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            // Explorer-Link
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallerie'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Einstellungen'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
          ],
        ),
      ),

      // Zeigt die aktuell ausgewählte Seite an, behält aber Zustand der anderen Seiten
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
    );
  }
}

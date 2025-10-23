import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme_provider.dart';
import '../utils/subscription_provider.dart';
import 'impressum_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedSeparator = '-';
  bool _loading = true;
  ThemeMode _selectedThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('filename_separator') ?? '-';
    final themeProvider =
        Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      // only accept actual symbols, default to '-'
      _selectedSeparator = (saved == '-' || saved == '_') ? saved : '-';
      _selectedThemeMode = themeProvider.mode;
      _loading = false;
    });
  }

  Future<void> _saveSettings(String separator) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filename_separator', separator);
    setState(() {
      _selectedSeparator = separator;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trennzeichen "$separator" gespeichert!'),
        backgroundColor: Colors.lightGreen.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final subscription = Provider.of<SubscriptionProvider>(context);
    final isPremium = subscription.isPremium;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Einstellungen',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Trennzeichen für Dateinamen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSeparator,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: '-', child: Text('Bindestrich  (-)')),
                  DropdownMenuItem(value: '_', child: Text('Unterstrich  (_)')),
                ],
                onChanged: (value) {
                  if (value != null) _saveSettings(value);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Benutzertyp (nur Entwicklung)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: isPremium ? 'premium' : 'standard',
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text('Standard (kein Premium)'),
                  ),
                  DropdownMenuItem(
                    value: 'premium',
                    child: Text('Premium'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  subscription.setPremium(value == 'premium');
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Darstellung',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThemeMode>(
                value: _selectedThemeMode,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Hell'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dunkel'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System folgen'),
                  ),
                ],
                onChanged: (mode) => _updateTheme(mode),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    isPremium
                        ? 'Premium aktiv'
                        : 'Upgrade auf Premium',
                  ),
                  onPressed: isPremium ? null : () => _upgradeToPremium(subscription),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _openImpressum,
                  child: const Text('Impressum'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTheme(ThemeMode? mode) async {
    if (mode == null) return;
    final provider = Provider.of<ThemeProvider>(context, listen: false);
    await provider.updateThemeMode(mode);
    setState(() => _selectedThemeMode = mode);
  }

  Future<void> _upgradeToPremium(SubscriptionProvider subscription) async {
    await subscription.setPremium(true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Premium wurde (zu Testzwecken) aktiviert.'),
        ),
      );
  }

  void _openImpressum() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ImpressumPage(),
      ),
    );
  }
}

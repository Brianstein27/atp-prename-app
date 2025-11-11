import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme_provider.dart';
import '../utils/subscription_provider.dart';
import 'impressum_page.dart';
import '../l10n/localization_helper.dart';

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
    if (!mounted) return;
    final saved = prefs.getString('filename_separator') ?? '-';
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
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
                context.tr(de: 'Einstellungen', en: 'Settings'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  de: 'Trennzeichen für Dateinamen',
                  en: 'Filename separator',
                ),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSeparator,
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: '-',
                    child: Text(
                      context.tr(de: 'Bindestrich  (-)', en: 'Hyphen  (-)'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: '_',
                    child: Text(
                      context.tr(
                        de: 'Unterstrich  (_)',
                        en: 'Underscore  (_)',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveSettings(value);
                },
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  de: 'Benutzertyp (nur Entwicklung)',
                  en: 'User type (dev only)',
                ),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: isPremium ? 'premium' : 'standard',
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text(
                      context.tr(
                        de: 'Standard (kein Premium)',
                        en: 'Standard (no premium)',
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'premium',
                    child: Text(context.tr(de: 'Premium', en: 'Premium')),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  subscription.setPremium(value == 'premium');
                },
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(de: 'Darstellung', en: 'Appearance'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThemeMode>(
                initialValue: _selectedThemeMode,
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(context.tr(de: 'Hell', en: 'Light')),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(context.tr(de: 'Dunkel', en: 'Dark')),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(
                      context.tr(de: 'System folgen', en: 'Follow system'),
                    ),
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
                        ? context.tr(de: 'Premium aktiv', en: 'Premium active')
                        : context.tr(
                            de: 'Upgrade auf Premium',
                            en: 'Upgrade to Premium',
                          ),
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
                  child: Text(
                    context.tr(de: 'Impressum', en: 'Imprint'),
                  ),
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
    if (!mounted) return;
    setState(() => _selectedThemeMode = mode);
  }

  Future<void> _upgradeToPremium(SubscriptionProvider subscription) async {
    await subscription.setPremium(true);
  }

  void _openImpressum() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ImpressumPage(),
      ),
    );
  }
}

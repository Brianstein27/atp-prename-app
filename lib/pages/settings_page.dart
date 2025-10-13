import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedSeparator = '-';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('filename_separator') ?? '-';
    setState(() {
      // only accept actual symbols, default to '-'
      _selectedSeparator = (saved == '-' || saved == '_') ? saved : '-';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        backgroundColor: Colors.lightGreen.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trennzeichen für Dateinamen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSeparator,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
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
          ],
        ),
      ),
    );
  }
}

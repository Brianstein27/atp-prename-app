import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/tag_input_row.dart';
import '../utils/camera_button.dart';
import '../utils/filename_preview.dart';

// Import nicht notwendig, aber zur Erinnerung für die Logik
// import 'package:photo_manager/photo_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- ZUSTANDSMANAGEMENT ---

  // 1. Tag A (Datum) - Der Controller für das nicht-editierbare Feld
  final String _dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
  // Verwendung von 'late' erfordert die Initialisierung in initState
  late final TextEditingController _dateController;
  bool _isDateTagEnabled = true;

  // 2. Tags B, C, D, E
  // Controller für die aktuellen Eingaben (im Fokus)
  final Map<String, TextEditingController> _tagControllers = {
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
    'E': TextEditingController(),
  };

  // 3. Bestätigte Tags für die Dateinamen-Logik
  // (Wird NUR bei onSubmitted aktualisiert, um die Vorschau zu steuern)
  Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
  };

  // 4. Reihenfolge der Tags (Schlüssel)
  List<String> _tagOrder = ['B', 'C', 'D', 'E'];

  // 5. Album Platzhalter
  String _selectedAlbumName = 'Projekt-Name-2025';

  @override
  void initState() {
    super.initState();

    // Initialisierung des Datum-Controllers, da er als 'late' deklariert ist.
    _dateController = TextEditingController(text: _dateTag);
  }

  @override
  void dispose() {
    // Controller aufräumen
    _dateController.dispose();
    _tagControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // --- LOGIK METHODEN ---

  // Wird aufgerufen, wenn Enter gedrückt oder Fokus verloren wird
  void _confirmTagValue(String key, String value) {
    setState(() {
      // Tags werden immer in Großbuchstaben gespeichert
      _confirmedTagValues[key] = value;
    });
  }

  // Wird aufgerufen, wenn ein Element in der ReorderableListView verschoben wird
  void _reorderTags(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String tag = _tagOrder.removeAt(oldIndex);
      _tagOrder.insert(newIndex, tag);
    });
  }

  // Generiert den finalen Dateinamen basierend auf bestätigten Werten und Reihenfolge
  String _generateFilename() {
    // 1. Tag A (Datum)
    String name = _isDateTagEnabled ? _dateTag : '';

    // 2. Sortierte Tags (B, C, D, E)
    for (var key in _tagOrder) {
      String tagValue = _confirmedTagValues[key]!;
      if (tagValue.isNotEmpty) {
        // Fügt einen Trennstrich hinzu, falls der Name nicht leer ist
        name += (name.isNotEmpty ? '-' : '') + tagValue;
      }
    }

    // 3. Seriennummer (Platzhalter)
    name += (name.isNotEmpty ? '-' : '') + '001.jpg';

    return name;
  }

  // --- UI AUFBAU ---

  @override
  Widget build(BuildContext context) {
    final String currentFilename = _generateFilename();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto Prename App'),
        backgroundColor: Colors.blueGrey.shade100,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Speicheralbum Auswahl
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(
                  Icons.photo_album,
                  color: Colors.blueGrey.shade700,
                ),
                title: const Text('Speicherort (Album)'),
                subtitle: Text(
                  _selectedAlbumName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Album Auswahl / Erstellungs-Logik (photo_manager)
                },
              ),
            ),

            const SizedBox(height: 16),

            // 2. Dateiname-Vorschau
            FilenamePreview(filename: currentFilename),

            const SizedBox(height: 24),

            // 3. Tag A (Datum) und Switch
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TagInputRow(
                        tagLabel: 'A',
                        controller:
                            _dateController, // Controller mit Datumswert
                        onSubmitted: (v) {}, // Deaktiviert
                        isEditable: false, // Nicht editierbar
                        isReorderable: false,
                      ),
                    ),
                    Switch(
                      value: _isDateTagEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isDateTagEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 32),
            const SizedBox(height: 8),

            // 4. Sortierbare Tag-Eingaben (B, C, D, E)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: _reorderTags,
              proxyDecorator: (widget, index, animation) {
                // Visueller Effekt beim Ziehen
                return Material(elevation: 6.0, child: widget);
              },
              children: _tagOrder.map((key) {
                return Container(
                  key: ValueKey(
                    key,
                  ), // Eindeutiger Key ist notwendig für ReorderableListView
                  child: TagInputRow(
                    tagLabel: key,
                    controller: _tagControllers[key]!,
                    // Update der Vorschau NUR bei Bestätigung
                    onSubmitted: (value) => _confirmTagValue(key, value),
                    isEditable: true,
                    isReorderable: true,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // 5. Kamera Button
            CameraButton(
              filename: currentFilename,
              selectedAlbumName: _selectedAlbumName,
              onCameraPressed: () {
                // TODO: Kamera-Aufruf Logik (image_picker + photo_manager Speicherung)
              },
            ),
          ],
        ),
      ),
    );
  }
}

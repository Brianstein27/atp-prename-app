import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import für Provider
import 'package:photo_manager/photo_manager.dart'; // Import für AssetPathEntity

import '../utils/tag_input_row.dart';
import '../utils/camera_button.dart';
import '../utils/filename_preview.dart';
import '../utils/album_manager.dart'; // Import des Managers

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- ZUSTANDSMANAGEMENT ---

  // 1. Tag A (Datum)
  final String _dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
  late final TextEditingController _dateController;
  bool _isDateTagEnabled = true;

  // 2. Tags B, C, D, E
  final Map<String, TextEditingController> _tagControllers = {
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
    'E': TextEditingController(),
  };

  // 3. Bestätigte Tags für die Dateinamen-Logik
  Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
  };

  // 4. Reihenfolge der Tags (Schlüssel)
  List<String> _tagOrder = ['B', 'C', 'D', 'E'];

  // 5. Controller für das Namensfeld bei der Album-Erstellung
  final TextEditingController _albumNameController = TextEditingController();

  // 6. Dateizähler (Platzhalter, wird später durch tatsächliche Logik ersetzt)
  int _fileCounter = 1;


  @override
  void initState() {
    super.initState();

    // Initialisierung des Datum-Controllers
    _dateController = TextEditingController(text: _dateTag);

    // Laden der Alben direkt nach dem ersten Frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AlbumManager>(context, listen: false).loadAlbums();
    });
  }

  @override
  void dispose() {
    // Controller aufräumen
    _dateController.dispose();
    _tagControllers.forEach((key, controller) => controller.dispose());
    _albumNameController.dispose();
    super.dispose();
  }

  // --- LOGIK METHODEN ---

  // Wird aufgerufen, wenn Enter gedrückt oder Fokus verloren wird
  void _confirmTagValue(String key, String value) {
    setState(() {
      // Tags werden immer in Großbuchstaben gespeichert
      _confirmedTagValues[key] = value.toUpperCase();
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

    // 3. Seriennummer
    // Formatierung der Seriennummer als dreistellige Zahl
    final String counterString = _fileCounter.toString().padLeft(3, '0');
    name += (name.isNotEmpty ? '-' : '') + counterString + '.jpg';

    return name;
  }
  
  // --- UI-HELPER FÜR DIALOGE ---

  /// Zeigt eine Snackbar zur Statusmeldung an.
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// Führt die Album-Erstellung durch und zeigt Feedback an.
  void _handleCreateAlbum(AlbumManager albumManager, String albumName) async {
    if (albumName.isNotEmpty) {
      final success = await albumManager.createAlbum(albumName);
      _showSnackbar(
        success
            ? 'Album "$albumName" erfolgreich erstellt.'
            : 'Fehler beim Erstellen des Albums.',
      );
    } else {
      _showSnackbar('Album-Name darf nicht leer sein.');
    }
  }

  /// Zeigt den Dialog zur Eingabe eines neuen Album-Namens an.
  Future<void> _showCreateAlbumDialog() async {
    _albumNameController.clear();
    final AlbumManager albumManager = Provider.of<AlbumManager>(
      context,
      listen: false,
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Neues Album erstellen'),
          content: TextField(
            controller: _albumNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Album-Name eingeben'),
            onSubmitted: (name) {
              // Optionale Aktion bei Eingabe mit Enter
              Navigator.of(context).pop();
              _handleCreateAlbum(albumManager, name);
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Erstellen'),
              onPressed: () {
                Navigator.of(context).pop(); // Dialog schließen
                _handleCreateAlbum(
                  albumManager,
                  _albumNameController.text.trim(),
                );
              },
            ),
          ],
        );
      },
    );
  }


  /// Zeigt den Album-Auswahl-Dialog an.
  Future<void> _showAlbumSelectionDialog(AlbumManager albumManager) async {
    if (!albumManager.hasPermission) {
      // Wenn Berechtigung fehlt, versuchen, sie anzufordern
      await albumManager.loadAlbums();
      if (!albumManager.hasPermission) {
        _showSnackbar(
          'Berechtigung fehlt! Bitte in den Einstellungen erteilen.',
        );
        return;
      }
    }

    if (albumManager.albums.isEmpty) {
      // Wenn keine Alben gefunden wurden, direkt zum Erstellungs-Dialog springen.
      _showSnackbar('Keine Alben gefunden. Bitte erstellen Sie zuerst eines.');
      _showCreateAlbumDialog();
      return;
    }

    // Zeigt den Dialog mit der Liste der verfügbaren Alben
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Album auswählen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albumManager.albums.length,
              itemBuilder: (context, index) {
                final album = albumManager.albums[index];
                return ListTile(
                  title: Text(album.name),
                  // KORRIGIERT: Verwenden von assetCountAsync, da dies die korrekte asynchrone Methode ist
                  subtitle: FutureBuilder<int>(
                    // Wir fragen die Anzahl der Bilder in diesem Album ab
                    future: album.assetCountAsync, // Korrekter Aufruf
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text('$count Bilder/Videos');
                    },
                  ),
                  leading: const Icon(Icons.folder_open),
                  trailing: albumManager.selectedAlbum?.id == album.id
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    albumManager.selectAlbum(album);
                    Navigator.pop(context); // Dialog schließen
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Nur Dialog schließen
              },
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Album-Dialog schließen
                _showCreateAlbumDialog(); // Neuen Dialog öffnen
              },
              child: const Text('Album erstellen'),
            ),
          ],
        );
      },
    );
  }

  // --- UI AUFBAU ---

  @override
  Widget build(BuildContext context) {
    final String currentFilename = _generateFilename();

    // Der Consumer reagiert auf Änderungen im AlbumManager
    return Consumer<AlbumManager>(
      builder: (context, albumManager, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Foto Prename App'),
            backgroundColor: Colors.blueGrey.shade100,
          ),
          body: SingleChildScrollView(
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
                    // Zeigt den aktuellen Namen aus dem Manager an
                    subtitle: Text(
                      albumManager.selectedAlbumName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    // Ruft den neuen Auswahl-Dialog auf
                    onTap: () => _showAlbumSelectionDialog(albumManager),
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
                            controller: _dateController,
                            onSubmitted: (v) {},
                            isEditable: false,
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
                    return Material(elevation: 6.0, child: widget);
                  },
                  children: _tagOrder.map((key) {
                    return Container(
                      key: ValueKey(key),
                      child: TagInputRow(
                        tagLabel: key,
                        controller: _tagControllers[key]!,
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
                  selectedAlbumName: albumManager.selectedAlbumName,
                  onCameraPressed: () {
                    // TODO: Kamera-Aufruf Logik (image_picker + photo_manager Speicherung)
                    _showSnackbar(
                      'Kamera-Logik muss noch implementiert werden!',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

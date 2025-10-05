import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../utils/tag_input_row.dart';
import '../utils/camera_button.dart';
import '../utils/filename_preview.dart';
import '../utils/album_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- ZUSTANDSMANAGEMENT ---

  // 1. Tag A (Datum)
  String get _dateTag => DateFormat('yyyyMMdd').format(DateTime.now());
  // KORREKTUR: Direkte Initialisierung, um LateInitializationError zu vermeiden.
  // Setzt den Wert auf das aktuelle Datum.
  late final TextEditingController _dateController = TextEditingController(
    text: _dateTag,
  );
  bool _isDateTagEnabled = true;

  // 2. Tags B, C, D, E
  final Map<String, TextEditingController> _tagControllers = {
    'B': TextEditingController(text: ''),
    'C': TextEditingController(text: ''),
    'D': TextEditingController(text: ''),
    'E': TextEditingController(text: ''),
  };

  // 3. Bestätigte Tags für die Dateinamen-Logik
  Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
  };

  // 4. Reihenfolge der Tags (Schlüssel) - Nur B, C, D, E sind verschiebbar
  List<String> _tagOrder = ['B', 'C', 'D', 'E'];

  // 5. Controller für das Namensfeld bei der Album-Erstellung
  final TextEditingController _albumNameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialisiere die bestätigten Werte, da die Controller auch Text haben
    _tagControllers.forEach((key, controller) {
      _confirmedTagValues[key] = controller.text;
    });

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
    if (key == 'A') {
      // Tag A wird nur über den Switch gesteuert und ist nicht manuell editierbar
      return;
    }
    setState(() {
      // Tags werden immer in Großbuchstaben gespeichert
      _confirmedTagValues[key] = value.trim();
      // Zähler neu berechnen lassen
      Provider.of<AlbumManager>(context, listen: false).getNextFileCounter();
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

      // Zähler neu berechnen lassen, da die Reihenfolge der Tags relevant ist
      Provider.of<AlbumManager>(context, listen: false).getNextFileCounter();
    });
  }

  // Generiert den finalen Dateinamen basierend auf bestätigten Werten und Reihenfolge
  String _generateFilename(int counter) {
    final List<String> parts = [];

    // 1. Tag A (Datum) - Hängt vom Switch ab (AN/AUS)
    // KORRIGIERTE LOGIK: Füge Tag A nur hinzu, wenn der Switch AN ist.
    if (_isDateTagEnabled) {
      final dateValue = _dateController.text.trim().toUpperCase();
      if (dateValue.isNotEmpty) {
        parts.add(dateValue);
      }
    }

    // 2. Sortierte Tags (B, C, D, E)
    for (var key in _tagOrder) {
      String tagValue = _confirmedTagValues[key]!;
      if (tagValue.isNotEmpty) {
        parts.add(tagValue);
      }
    }

    // Kombiniere alle Tag-Teile
    String name = parts.join('-');

    // 3. Seriennummer
    final String counterString = counter.toString().padLeft(3, '0');
    // Die Seriennummer wird immer hinzugefügt
    if (name.isNotEmpty) {
      name += '-' + counterString;
    } else {
      // Wenn alles leer ist, nur die Nummer verwenden
      name = counterString;
    }

    return name + '.jpg';
  }

  /// Öffnet die Kamera, nimmt ein Bild auf und speichert es
  /// mit dem generierten Dateinamen im ausgewählten Album.
  Future<void> _takePictureAndSave() async {
    final picker = ImagePicker();
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    // NEUE PRÜFUNG: Überprüft, ob ein Album oder ein temporärer Name ausgewählt ist
    if (albumManager.selectedAlbum == null &&
        albumManager.selectedAlbumName == 'Pictures') {
      _showSnackbar(
        'Fehler: Bitte zuerst ein Album auswählen oder erstellen.',
        error: true,
      );
      return;
    }

    // Generiere den Dateinamen VOR der Aufnahme
    final filename = _generateFilename(albumManager.currentFileCounter);

    // 1. Kamera öffnen und Bild aufnehmen
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);

      // Zeige Lade-Indikator
      _showLoadingDialog();

      try {
        // 2. Bild mit generiertem Namen im Album speichern (Manager kümmert sich um den Namen/die Entity)
        await albumManager.saveImage(imageFile, filename);

        // 3. Nach erfolgreicher Speicherung den aktuellen Dateizähler aktualisieren
        await albumManager.getNextFileCounter();

        // Zeige Bestätigung
        Navigator.of(context).pop(); // Lade-Dialog schließen
        // HINWEIS: selectedAlbumName ist jetzt der temporär gespeicherte Name

        // Prüfen, ob das Album jetzt gefunden wurde (selectedAlbum ist nicht mehr null)
        if (albumManager.selectedAlbum != null) {
          _showSnackbar(
            'Bild erfolgreich als "$filename" in "${albumManager.selectedAlbumName}" gespeichert.',
          );
        } else {
          _showSnackbar(
            'Bild erfolgreich als "$filename" gespeichert. '
            'HINWEIS: Dieses erste Bild landete im Standardordner, aber der Zielordner "${albumManager.selectedAlbumName}" '
            'sollte jetzt indiziert sein. Wählen Sie es manuell aus dem Album-Dialog aus.',
            error: true,
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Lade-Dialog schließen
        debugPrint('Speicherfehler: $e');
        _showSnackbar(
          'Das Bild konnte nicht gespeichert werden: $e',
          error: true,
        );
      }
    }
  }

  // --- UI-HELPER FÜR DIALOGE & SNACKBAR ---

  /// Zeigt eine Snackbar zur Statusmeldung an.
  void _showSnackbar(String message, {bool error = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: error
              ? Colors.red.shade700
              : Colors.blueGrey.shade700,
        ),
      );
    }
  }

  /// Zeigt einen Lade-Dialog an, der nicht geschlossen werden kann.
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Speichere Bild...", style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  void _handleCreateAlbum(AlbumManager albumManager, String albumName) async {
    final cleanedName = albumName.trim();

    if (cleanedName.isNotEmpty) {
      // 1. Album erstellen (ruft die Logik im Manager auf, die den Namen persistent setzt)
      await albumManager.createAlbum(cleanedName);

      // 2. Erneut versuchen, die Entity zu finden.
      // Der Manager hat den Namen jetzt gesetzt. Wir können eine generische Erfolgsmeldung senden.

      albumManager.getNextFileCounter();

      _showSnackbar(
        'Album "$cleanedName" erfolgreich erstellt und als Speicherort ausgewählt. '
        'Hinweis: Das Album ist eventuell erst nach dem ersten gespeicherten Bild in der Liste sichtbar.',
      );
    } else {
      _showSnackbar('Album-Name darf nicht leer sein.', error: true);
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
            ElevatedButton(
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
      await albumManager.loadAlbums();
      if (!albumManager.hasPermission) {
        _showSnackbar(
          'Berechtigung fehlt! Bitte in den Einstellungen erteilen.',
          error: true,
        );
        return;
      }
    }

    if (albumManager.albums.isEmpty) {
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
                  subtitle: FutureBuilder<int>(
                    // Wir fragen die Anzahl der Bilder in diesem Album ab
                    future: album.assetCountAsync,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text('$count Bilder/Videos');
                    },
                  ),
                  leading: const Icon(Icons.folder_open),
                  trailing: albumManager.selectedAlbum?.id == album.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectAlbum(album);
                    // Nach Albumauswahl Zähler neu berechnen
                    albumManager.getNextFileCounter();
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
    // Stellen Sie sicher, dass der Date-Controller immer das aktuelle Datum anzeigt.
    // Das ist wichtig, da der Controller readOnly ist und der Wert sonst veraltet.
    _dateController.text = _dateTag;

    // Der Consumer reagiert auf Änderungen im AlbumManager
    return Consumer<AlbumManager>(
      builder: (context, albumManager, child) {
        final String currentFilename = _generateFilename(
          albumManager.currentFileCounter,
        );

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Speicheralbum Auswahl
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(
                      Icons.photo_album,
                      color: Colors.lightGreen.shade700,
                      size: 32,
                    ),
                    title: const Text('Speicherort (Album)'),
                    // Zeigt den aktuellen Namen aus dem Manager an
                    subtitle: Text(
                      albumManager.selectedAlbumName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAlbumSelectionDialog(albumManager),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Dateiname-Vorschau
                FilenamePreview(
                  filename: currentFilename,
                  counter: albumManager.currentFileCounter,
                ),

                const SizedBox(height: 24),

                // 3. Tag A (Datum) und Switch
                Container(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TagInputRow(
                            tagLabel: 'A',
                            controller: _dateController,
                            onSubmitted: (v) {}, // Deaktiviert
                            // IMMER readOnly: Tag A ist immer Datum
                            isEditable: false,
                            isReorderable: false, // Nicht verschiebbar
                          ),
                        ),
                        Switch(
                          value: _isDateTagEnabled,
                          activeColor: Colors.lightGreen,
                          onChanged: (value) {
                            setState(() {
                              _isDateTagEnabled = value;
                              // Beim Wechsel Zähler neu berechnen lassen
                              albumManager.getNextFileCounter();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

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
                    return Padding(
                      key: ValueKey(key),
                      padding: const EdgeInsets.only(bottom: 8.0),
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
                  onCameraPressed: _takePictureAndSave,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

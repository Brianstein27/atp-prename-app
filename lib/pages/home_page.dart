import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/tag_input_row.dart';
import '../utils/camera_button.dart';
import '../utils/filename_preview.dart';
import '../utils/album_manager.dart';
import 'camera_capture_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _dateTag => DateFormat('yyyyMMdd').format(DateTime.now());
  late final TextEditingController _dateController = TextEditingController(
    text: _dateTag,
  );

  bool _isDateTagEnabled = true;
  bool _isVideoMode = false;
  String _separator = '-';

  final Map<String, TextEditingController> _tagControllers = {
    'B': TextEditingController(),
    'C': TextEditingController(),
    'D': TextEditingController(),
    'E': TextEditingController(),
  };

  Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
  };

  List<String> _tagOrder = ['B', 'C', 'D', 'E'];
  final TextEditingController _albumNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AlbumManager>(context, listen: false).loadAlbums();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _separator = prefs.getString('filename_separator') ?? '-';
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _albumNameController.dispose();
    _tagControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  void _confirmTagValue(String key, String value) {
    setState(() {
      _confirmedTagValues[key] = value.trim().toUpperCase();
    });
  }

  void _reorderTags(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final tag = _tagOrder.removeAt(oldIndex);
      _tagOrder.insert(newIndex, tag);
    });
  }

  Future<String> _generateFilename({bool isVideo = false}) async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
    final parts = <String>[];

    if (_isDateTagEnabled) {
      final date = _dateController.text.trim();
      if (date.isNotEmpty) parts.add(date);
    }

    for (var key in _tagOrder) {
      final val = _confirmedTagValues[key]!;
      if (val.isNotEmpty) parts.add(val);
    }

    final nextCount = await albumManager.getNextAvailableCounterForTags(parts);
    final ext = isVideo ? '.mp4' : '.jpg';
    return parts.join(_separator) +
        _separator +
        nextCount.toString().padLeft(3, '0') +
        ext;
  }

  // 📸 FOTO AUFNEHMEN
  Future<void> _takePictureAndSave() async {
    final picker = ImagePicker();
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (albumManager.selectedAlbum == null &&
        albumManager.selectedAlbumName == 'Pictures') {
      _showSnackbar('Bitte zuerst ein Album auswählen.', error: true);
      return;
    }

    final filename = await _generateFilename();

    final confirmed = await _showConfirmationDialog(
      title: 'Foto aufnehmen?',
      message:
          'Das Bild wird im Album "${albumManager.selectedAlbumName}" gespeichert und erhält den Dateinamen:\n\n$filename',
      confirmText: 'Aufnehmen',
    );

    if (confirmed != true) return;

    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      _showLoadingDialog();
      try {
        await albumManager.saveImage(imageFile, filename);
        Navigator.pop(context);
        _showSnackbar('✅ Foto "$filename" gespeichert.');
      } catch (e) {
        Navigator.pop(context);
        _showSnackbar('❌ Fehler beim Speichern: $e', error: true);
      }
    }
  }

  // 🎥 VIDEO AUFNEHMEN
  Future<void> _recordVideoAndSave() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (albumManager.selectedAlbum == null &&
        albumManager.selectedAlbumName == 'Pictures') {
      _showSnackbar('Bitte zuerst ein Album auswählen.', error: true);
      return;
    }

    final filename = await _generateFilename(isVideo: true);

    final confirmed = await _showConfirmationDialog(
      title: 'Video aufnehmen?',
      message:
          'Das Video wird im Album "${albumManager.selectedAlbumName}" gespeichert und erhält den Dateinamen:\n\n$filename',
      confirmText: 'Aufnehmen',
    );

    if (confirmed != true) return;

    // 🚀 Kamera-Seite öffnen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCapturePage(
          isVideoMode: true,
          filename: filename,
          onMediaCaptured: (File videoFile) async {
            _showLoadingDialog();
            try {
              await albumManager.saveVideo(videoFile, filename);
              Navigator.pop(context); // loading schließen
              _showSnackbar('✅ Video "$filename" gespeichert.');
            } catch (e) {
              Navigator.pop(context);
              _showSnackbar('❌ Fehler beim Speichern: $e', error: true);
            }
          },
        ),
      ),
    );
  }

  // 🔧 HILFSMETHODEN
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Speichere...'),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlbumSelectionDialog(AlbumManager albumManager) async {
    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
      if (!albumManager.hasPermission) {
        _showSnackbar(
          'Berechtigung fehlt. Bitte in den Einstellungen erteilen.',
          error: true,
        );
        return;
      }
    }

    await albumManager.loadAlbums();

    if (albumManager.albums.isEmpty) {
      _showSnackbar('Keine Alben gefunden. Bitte eines erstellen.');
      _showCreateAlbumDialog(albumManager);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Album auswählen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albumManager.albums.length,
              itemBuilder: (context, index) {
                final album = albumManager.albums[index];
                if (album.name.toLowerCase() == 'recents') {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  title: Text(album.name),
                  subtitle: FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) {
                      return Text('${snapshot.data ?? 0} Elemente');
                    },
                  ),
                  trailing: albumManager.selectedAlbum?.id == album.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectAlbum(album);
                    Navigator.pop(context);
                    _showSnackbar('Album "${album.name}" ausgewählt.');
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreateAlbumDialog(albumManager);
              },
              child: const Text('Neues Album'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateAlbumDialog(AlbumManager albumManager) async {
    _albumNameController.clear();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Neues Album erstellen'),
          content: TextField(
            controller: _albumNameController,
            decoration: const InputDecoration(hintText: 'Albumname eingeben'),
            autofocus: true,
            onSubmitted: (value) async {
              Navigator.pop(context);
              await _handleCreateAlbum(albumManager, value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _handleCreateAlbum(
                  albumManager,
                  _albumNameController.text,
                );
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCreateAlbum(
    AlbumManager albumManager,
    String name,
  ) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      _showSnackbar('Albumname darf nicht leer sein.', error: true);
      return;
    }

    await albumManager.createAlbum(cleanedName);
    _showSnackbar('Album "$cleanedName" erstellt und ausgewählt.');
  }

  // 🧱 UI
  @override
  Widget build(BuildContext context) {
    return Consumer<AlbumManager>(
      builder: (context, albumManager, _) {
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.photo_album, size: 32),
                    title: const Text('Speicherort (Album)'),
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
                FutureBuilder<String>(
                  future: _generateFilename(isVideo: _isVideoMode),
                  builder: (context, snapshot) {
                    return FilenamePreview(
                      filename: snapshot.data ?? '...',
                      counter: albumManager.currentFileCounter,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TagInputRow(
                        tagLabel: 'A',
                        controller: _dateController,
                        onSubmitted: (_) {},
                        isEditable: false,
                        isReorderable: false,
                      ),
                    ),
                    Switch(
                      value: _isDateTagEnabled,
                      onChanged: (v) => setState(() => _isDateTagEnabled = v),
                      activeColor: Colors.lightGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: _reorderTags,
                  children: _tagOrder.map((key) {
                    return Padding(
                      key: ValueKey(key),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TagInputRow(
                        tagLabel: key,
                        controller: _tagControllers[key]!,
                        onSubmitted: (v) => _confirmTagValue(key, v),
                        isEditable: true,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                CameraButton(
                  filename: '',
                  selectedAlbumName: albumManager.selectedAlbumName,
                  onCameraPressed: _takePictureAndSave,
                  onVideoPressed: _recordVideoAndSave,
                  onModeChanged: (isVideo) =>
                      setState(() => _isVideoMode = isVideo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

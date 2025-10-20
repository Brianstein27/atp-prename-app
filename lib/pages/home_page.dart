import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/tag_input_row.dart';
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

  Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
    'F': '',
  };

  List<String> _tagOrder = ['B', 'C', 'D', 'E', 'F'];
  final TextEditingController _albumNameController = TextEditingController();
  final Map<String, List<String>> _savedTags = {
    'B': [],
    'C': [],
    'D': [],
    'E': [],
    'F': [],
  };

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
      for (final key in _savedTags.keys) {
        _savedTags[key] = List<String>.from(
          prefs.getStringList('tag_memory_$key') ?? const [],
        );
      }
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _albumNameController.dispose();
    super.dispose();
  }

  void _reorderTags(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final tag = _tagOrder.removeAt(oldIndex);
      _tagOrder.insert(newIndex, tag);
    });
  }

  Future<void> _handleTagSubmit(String key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.length > 20) {
      _showSnackbar('Maximal 20 Zeichen pro Tag.', error: true);
      return;
    }

    final current = _savedTags[key]!;
    final isNew = !current.contains(trimmed);

    setState(() {
      _confirmedTagValues[key] = trimmed;
      if (isNew) {
        current.add(trimmed);
      }
    });

    if (isNew) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tag_memory_$key', current);
      _showSnackbar('Tag "$trimmed" gespeichert.');
    }
  }

  Future<void> _deleteSavedTag(String key, String value) async {
    final current = _savedTags[key]!;
    if (!current.contains(value)) return;

    setState(() {
      current.remove(value);
      if (_confirmedTagValues[key] == value) {
        _confirmedTagValues[key] = '';
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tag_memory_$key', current);
    _showSnackbar('Tag "$value" gelöscht.');
  }

  void _clearTag(String key) {
    setState(() {
      _confirmedTagValues[key] = '';
    });
  }

  Future<void> _showTagPicker(String key) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _TagPickerSheet(
          tagLabel: key,
          savedTags: List<String>.from(_savedTags[key]!),
          currentValue: _confirmedTagValues[key] ?? '',
          onDeleteTag: (tag) async {
            await _deleteSavedTag(key, tag);
          },
        );
      },
    );

    if (selected != null) {
      await _handleTagSubmit(key, selected);
    }
  }

  Future<String> _generateFilename({bool isVideo = false}) async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
    final parts = <String>[];

    if (_isDateTagEnabled) {
      final date = _dateController.text.trim();
      if (date.isNotEmpty) parts.add(date);
    }

    for (final key in _tagOrder) {
      final val = _confirmedTagValues[key]!;
      if (val.isNotEmpty) parts.add(val);
    }

    final nextCount = await albumManager.getNextAvailableCounterForTags(
      parts,
      separator: _separator,
    );
    final ext = isVideo ? '.mp4' : '.jpg';
    return parts.join(_separator) +
        _separator +
        nextCount.toString().padLeft(3, '0') +
        ext;
  }

  // 🔧 HILFSMETHODEN

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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Album auswählen',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Kein Album ausgewählt'),
                  trailing:
                      albumManager.selectedAlbumName ==
                          albumManager.baseFolderName
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectDefaultAlbum();
                    Navigator.pop(context);
                    _showSnackbar(
                      'Album "${albumManager.baseFolderName}" ausgewählt.',
                    );
                  },
                ),
                const Divider(),
                if (albumManager.albums
                    .where(
                      (a) =>
                          a.name != albumManager.baseFolderName &&
                          a.name.toLowerCase() != 'recents',
                    )
                    .isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Noch keine weiteren Alben vorhanden.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ...albumManager.albums
                      .where((album) {
                        if (album.name.toLowerCase() == 'recents') return false;
                        if (album.name == albumManager.baseFolderName) {
                          return false;
                        }
                        return true;
                      })
                      .map((album) {
                        return ListTile(
                          title: Text(album.name),
                          subtitle: FutureBuilder<int>(
                            future: album.assetCountAsync,
                            builder: (context, snapshot) {
                              return Text('${snapshot.data ?? 0} Elemente');
                            },
                          ),
                          trailing: albumManager.selectedAlbum?.id == album.id
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: () {
                            albumManager.selectAlbum(album);
                            Navigator.pop(context);
                            _showSnackbar('Album "${album.name}" ausgewählt.');
                          },
                        );
                      })
                      .toList(),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: 'Neues Album',
              onPressed: () {
                Navigator.pop(context);
                _showCreateAlbumDialog(albumManager);
              },
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
          title: const Text('Neues Album'),
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
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                Navigator.pop(context);
                await _handleCreateAlbum(
                  albumManager,
                  _albumNameController.text,
                );
              },
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF243227)
                      : Theme.of(context).cardTheme.color,
                  elevation: Theme.of(context).brightness == Brightness.dark
                      ? 4
                      : 2,
                  shadowColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black45
                      : Theme.of(context).shadowColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.photo_album,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Ausgewähltes Album'),
                    subtitle: Text(
                      albumManager.selectedAlbumName ==
                              albumManager.baseFolderName
                          ? 'Kein Album ausgewählt'
                          : albumManager.selectedAlbumName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _showAlbumSelectionDialog(albumManager),
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<String>(
                  future: _generateFilename(isVideo: _isVideoMode),
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? '...';
                    return FilenamePreview(
                      filename: name,
                      counter: albumManager.currentFileCounter,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DateTagRow(
                        controller: _dateController,
                        isEnabled: _isDateTagEnabled,
                      ),
                    ),
                Switch(
                  value: _isDateTagEnabled,
                  onChanged: (v) => setState(() => _isDateTagEnabled = v),
                  activeColor: Theme.of(context).colorScheme.primary,
                  thumbColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context).colorScheme.primary;
                    }
                    return Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant;
                  }),
                  trackColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.35);
                    }
                    return Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.6);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.2),
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
                        value: _confirmedTagValues[key] ?? '',
                        placeholder: 'Tag $key eingeben',
                        onTap: () => _showTagPicker(key),
                        onClear: _confirmedTagValues[key]?.isNotEmpty == true
                            ? () => _clearTag(key)
                            : null,
                        isReorderable: true,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera öffnen'),
                    onPressed: () async {
                      final albumManager = Provider.of<AlbumManager>(
                        context,
                        listen: false,
                      );
                      if (albumManager.selectedAlbum == null &&
                          albumManager.selectedAlbumName.isEmpty) {
                        _showSnackbar(
                          'Bitte zuerst ein Album auswählen.',
                          error: true,
                        );
                        return;
                      }

                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraCapturePage(
                            initialVideoMode: _isVideoMode,
                            requestFilename: (isVideo) =>
                                _generateFilename(isVideo: isVideo),
                            onMediaCaptured:
                                (
                                  File file,
                                  String filename,
                                  bool isVideo,
                                ) async {
                                  _showLoadingDialog();
                                  try {
                                    if (isVideo) {
                                      await albumManager.saveVideo(
                                        file,
                                        filename,
                                      );
                                    } else {
                                      await albumManager.saveImage(
                                        file,
                                        filename,
                                      );
                                    }
                                    if (mounted) Navigator.pop(context);
                                    _showSnackbar(
                                      '✅ ${isVideo ? "Video" : "Foto"} "$filename" gespeichert.',
                                    );
                                  } catch (e) {
                                    if (mounted) Navigator.pop(context);
                                    _showSnackbar(
                                      '❌ Fehler beim Speichern: $e',
                                      error: true,
                                    );
                                  }
                                },
                          ),
                        ),
                      );

                      if (mounted && result != null) {
                        setState(() => _isVideoMode = result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateTagRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isEnabled;

  const _DateTagRow({required this.controller, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text(
            'A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? scheme.primary
                    : scheme.outlineVariant.withOpacity(0.6),
              ),
              color: isDark ? const Color(0xFF273429) : Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TagPickerSheet extends StatefulWidget {
  final String tagLabel;
  final List<String> savedTags;
  final String currentValue;
  final Future<void> Function(String) onDeleteTag;

  const _TagPickerSheet({
    super.key,
    required this.tagLabel,
    required this.savedTags,
    required this.currentValue,
    required this.onDeleteTag,
  });

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late final TextEditingController _controller;
  late List<String> _tags;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = List<String>.from(widget.savedTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCreateTag() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Bitte einen Tag eingeben.');
      return;
    }
    if (trimmed.length > 20) {
      setState(() => _errorText = 'Maximal 20 Zeichen.');
      return;
    }
    Navigator.pop(context, trimmed);
  }

  Future<void> _handleDelete(String tag) async {
    await widget.onDeleteTag(tag);
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomInset + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tag ${widget.tagLabel} auswählen',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: 'Neuen Tag hinzufügen',
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Tag speichern und auswählen',
                  onPressed: _handleCreateTag,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _handleCreateTag(),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorText!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            if (_tags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Noch keine Tags gespeichert.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    final isSelected = widget.currentValue == tag;
                    return ListTile(
                      dense: true,
                      onTap: () => Navigator.pop(context, tag),
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? Colors.lightGreen.shade600
                            : Colors.grey.shade400,
                      ),
                      title: Text(tag),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Tag löschen',
                        onPressed: () => _handleDelete(tag),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

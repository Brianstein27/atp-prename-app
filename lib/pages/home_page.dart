import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/tag_input_row.dart';
import '../utils/filename_preview.dart';
import '../utils/album_manager.dart';
import '../utils/subscription_provider.dart';
import 'camera_capture_page.dart';
import '../l10n/localization_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  String get _currentDateValue => DateFormat('yyyyMMdd').format(DateTime.now());
  late final TextEditingController _dateController = TextEditingController(
    text: 'yyyyMMdd',
  );

  bool _isDateTagEnabled = true;
  bool _isVideoMode = false;
  String _separator = '-';

  final Map<String, String> _confirmedTagValues = {
    'B': '',
    'C': '',
    'D': '',
    'E': '',
  };

  final List<String> _tagOrder = ['B', 'C', 'D', 'E'];
  final TextEditingController _albumNameController = TextEditingController();
  final Map<String, List<String>> _savedTags = {
    'B': [],
    'C': [],
    'D': [],
    'E': [],
  };

  bool _isPremium() {
    return Provider.of<SubscriptionProvider>(context, listen: false).isPremium;
  }

  bool _canUseTag(String key) {
    if (_isPremium()) return true;
    return key == 'B';
  }

  void _showPremiumPrompt() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(de: 'Premium erforderlich', en: 'Premium required'),
        ),
        content: Text(
          dialogContext.tr(
            de: 'Diese Funktion steht nur Premium-Nutzern zur Verfügung.',
            en: 'This feature is available to premium users only.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr(de: 'OK', en: 'OK')),
          ),
        ],
      ),
    );
  }

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

  @override
  bool get wantKeepAlive => true;

  void _reorderTags(int oldIndex, int newIndex) {
    if (!_isPremium()) {
      _showPremiumPrompt();
      return;
    }

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final tag = _tagOrder.removeAt(oldIndex);
      _tagOrder.insert(newIndex, tag);
    });
  }

  Future<void> _handleTagSubmit(String key, String value) async {
    if (!_canUseTag(key)) {
      _showPremiumPrompt();
      return;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.length > 20) {
      _showErrorMessage(
        context.tr(
          de: 'Maximal 20 Zeichen pro Tag.',
          en: 'Maximum of 20 characters per tag.',
        ),
      );
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
    }
  }

  Future<void> _deleteSavedTag(String key, String value) async {
    if (!_canUseTag(key)) {
      _showPremiumPrompt();
      return;
    }

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
  }

  void _clearTag(String key) {
    if (!_canUseTag(key)) {
      _showPremiumPrompt();
      return;
    }

    setState(() {
      _confirmedTagValues[key] = '';
    });
  }

  Future<void> _showTagPicker(String key) async {
    if (!_canUseTag(key)) {
      _showPremiumPrompt();
      return;
    }

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

  Future<String> _generateFilename({
    bool isVideo = false,
    bool reserve = false,
  }) async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
    final parts = <String>[];

    final dateValue = _currentDateValue;
    if (_isDateTagEnabled && dateValue.isNotEmpty) {
      parts.add(dateValue);
    }

    for (final key in _tagOrder) {
      if (!_canUseTag(key)) continue;
      final val = _confirmedTagValues[key]!;
      if (val.isNotEmpty) parts.add(val);
    }

    final nextCount = await albumManager.getNextAvailableCounterForTags(
      parts,
      separator: _separator,
      dateTagEnabled: _isDateTagEnabled,
      dateTag: _isDateTagEnabled ? dateValue : null,
      reserve: reserve,
    );
    final ext = isVideo ? '.mp4' : '.jpg';
    final baseName = parts.join(_separator);
    final counterStr = nextCount.toString().padLeft(3, '0');
    final joined = baseName.isEmpty
        ? counterStr
        : '$baseName$_separator$counterStr';
    return '$joined$ext';
  }

  // 🔧 HILFSMETHODEN

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
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
            _LoadingDialogText(),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlbumSelectionDialog(AlbumManager albumManager) async {
    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
      if (!albumManager.hasPermission) {
        _showErrorMessage(
          context.tr(
            de: 'Berechtigung fehlt. Bitte in den Einstellungen erteilen.',
            en: 'Missing permission. Please grant access in Settings.',
          ),
        );
        return;
      }
    }

    await albumManager.loadAlbums();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dialogContext.tr(de: 'Album auswählen', en: 'Choose album'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: dialogContext.tr(de: 'Schließen', en: 'Close'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(
                    dialogContext.tr(
                      de: 'Kein Album ausgewählt',
                      en: 'No album selected',
                    ),
                  ),
                  trailing:
                      albumManager.selectedAlbumName ==
                          albumManager.baseFolderName
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectDefaultAlbum();
                    Navigator.pop(dialogContext);
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
                      dialogContext.tr(
                        de: 'Noch keine weiteren Alben vorhanden.',
                        en: 'No additional albums yet.',
                      ),
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
                              final count = snapshot.data ?? 0;
                              return Text(
                                context.tr(
                                  de: '$count Elemente',
                                  en: '$count items',
                                ),
                              );
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
                            Navigator.pop(dialogContext);
                          },
                        );
                      }),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: dialogContext.tr(de: 'Neues Album', en: 'New album'),
              onPressed: () {
                Navigator.pop(dialogContext);
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
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr(de: 'Neues Album', en: 'New album')),
          content: TextField(
            controller: _albumNameController,
            decoration: InputDecoration(
              hintText: dialogContext.tr(
                de: 'Albumname eingeben',
                en: 'Enter album name',
              ),
            ),
            autofocus: true,
            onSubmitted: (value) async {
              Navigator.pop(dialogContext);
              await _handleCreateAlbum(albumManager, value);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                Navigator.pop(dialogContext);
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
      _showErrorMessage(
        context.tr(
          de: 'Albumname darf nicht leer sein.',
          en: 'Album name cannot be empty.',
        ),
      );
      return;
    }

    await albumManager.createAlbum(cleanedName);
  }

  // 🧱 UI
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final subscription = context.watch<SubscriptionProvider>();
    final isPremium = subscription.isPremium;

    if (!isPremium && !_isDateTagEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isDateTagEnabled = true);
      });
    }

    return Consumer<AlbumManager>(
      builder: (context, albumManager, _) {
        return Stack(
          children: [
            Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF243227)
                                  : Theme.of(context).cardTheme.color,
                              elevation:
                                  Theme.of(context).brightness == Brightness.dark
                                      ? 4
                                      : 2,
                              shadowColor:
                                  Theme.of(context).brightness == Brightness.dark
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
                                title: Text(
                                  context.tr(
                                    de: 'Ausgewähltes Album',
                                    en: 'Selected album',
                                  ),
                                ),
                                subtitle: Text(
                                  albumManager.selectedAlbumName ==
                                          albumManager.baseFolderName
                                      ? context.tr(
                                          de: 'Kein Album ausgewählt',
                                          en: 'No album selected',
                                        )
                                      : albumManager.selectedAlbumName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                onTap: () => _showAlbumSelectionDialog(
                                  albumManager,
                                ),
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
                                    isEnabled:
                                        isPremium ? _isDateTagEnabled : true,
                                  ),
                                ),
                                Switch(
                                  value: _isDateTagEnabled,
                                  onChanged: isPremium
                                      ? (v) =>
                                          setState(() => _isDateTagEnabled = v)
                                      : null,
                                  thumbColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Theme.of(context)
                                          .colorScheme
                                          .primary;
                                    }
                                    return Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant;
                                  }),
                                  trackColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Theme.of(
                                        context,
                                      ).colorScheme.primary.withValues(
                                            alpha: 0.35,
                                          );
                                    }
                                    return Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.6);
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: _reorderTags,
                              children: _tagOrder.map((key) {
                                final isLocked = !isPremium && key != 'B';
                                return Padding(
                                  key: ValueKey(key),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TagInputRow(
                                    tagLabel: key,
                                    value: _confirmedTagValues[key] ?? '',
                                    placeholder: isLocked
                                        ? context.tr(
                                            de: 'Premium erforderlich',
                                            en: 'Premium required',
                                          )
                                        : context.tr(
                                            de: 'Tag $key eingeben',
                                            en: 'Enter tag $key',
                                          ),
                                    onTap: () => _showTagPicker(key),
                                    onClear: (!isLocked &&
                                            _confirmedTagValues[key]
                                                    ?.isNotEmpty ==
                                                true)
                                        ? () => _clearTag(key)
                                        : null,
                                    isReorderable: isPremium,
                                    isLocked: isLocked,
                                    onLockedTap:
                                        isLocked ? _showPremiumPrompt : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            context.tr(de: 'Kamera', en: 'Camera'),
                          ),
                          onPressed: () async {
                            final albumManager = Provider.of<AlbumManager>(
                              context,
                              listen: false,
                            );
                            if (albumManager.selectedAlbum == null &&
                                albumManager.selectedAlbumName.isEmpty) {
                              _showErrorMessage(
                                context.tr(
                                  de: 'Bitte zuerst ein Album auswählen.',
                                  en: 'Please choose an album first.',
                                ),
                              );
                              return;
                            }

                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CameraCapturePage(
                                  initialVideoMode: _isVideoMode,
                                  requestFilename:
                                      (isVideo, {bool reserve = false}) =>
                                          _generateFilename(
                                            isVideo: isVideo,
                                            reserve: reserve,
                                          ),
                                  onMediaCaptured:
                                      (File file, String filename, bool isVideo) async {
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
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.tr(
                                                    de: '❌ Fehler beim Speichern: $e',
                                                    en: '❌ Error while saving: $e',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.red.shade700,
                                              ),
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (albumManager.isRecoveringAlbums)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.tr(
                                de: 'Scanne Medien nach früheren Projekten...',
                                en: 'Scanning media for previous projects...',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
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

class _LoadingDialogText extends StatelessWidget {
  const _LoadingDialogText();

  @override
  Widget build(BuildContext context) {
    return Text(context.tr(de: 'Speichere...', en: 'Saving...'));
  }
}

class _TagPickerSheet extends StatefulWidget {
  final String tagLabel;
  final List<String> savedTags;
  final String currentValue;
  final Future<void> Function(String) onDeleteTag;

  const _TagPickerSheet({
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
      setState(
        () => _errorText = context.tr(
          de: 'Bitte einen Tag eingeben.',
          en: 'Please enter a tag.',
        ),
      );
      return;
    }
    if (trimmed.length > 20) {
      setState(
        () => _errorText = context.tr(
          de: 'Maximal 20 Zeichen.',
          en: 'Maximum of 20 characters.',
        ),
      );
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
              context.tr(
                de: 'Tag ${widget.tagLabel} auswählen',
                en: 'Select tag ${widget.tagLabel}',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: context.tr(
                  de: 'Neuen Tag hinzufügen',
                  en: 'Add new tag',
                ),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: context.tr(
                    de: 'Tag speichern und auswählen',
                    en: 'Save and select tag',
                  ),
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
                  context.tr(
                    de: 'Noch keine Tags gespeichert.',
                    en: 'No tags saved yet.',
                  ),
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
                        tooltip: context.tr(
                          de: 'Tag löschen',
                          en: 'Delete tag',
                        ),
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

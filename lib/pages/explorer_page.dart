import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_helper.dart';
import '../utils/album_manager.dart';
import 'fullscreen_image_page.dart';
import 'video_player_page.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/subscription_provider.dart';

enum SortMode { date, name }

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  static const MethodChannel _iosMediaSaverChannel = MethodChannel('com.atp.PhotoTagger/ios_media_saver');
  SortMode _sortMode = SortMode.date;
  List<AssetEntity> _photos = [];
  List<AssetEntity> _filteredPhotos = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  bool _isAscending = false;
  String _searchQuery = '';
  Set<AssetEntity> _selectedItems = {};
  late final TextEditingController _searchController;
  final Map<String, String> _assetAlbumNames = {};
  final Map<String, String> _displayNameOverrides = {};
  bool _hasShownIosRenameWarning = false;

  bool _isPremiumUser() {
    return Provider.of<SubscriptionProvider>(context, listen: false).isPremium;
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
    _searchController = TextEditingController(text: _searchQuery);
    _searchController.addListener(_onSearchChanged);
    _loadCurrentAlbumPhotos();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAlbumPhotos() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
    }

    final selectedAlbum = albumManager.selectedAlbum;

    final isPremium = _isPremiumUser();

    if (!isPremium && _sortMode == SortMode.name) {
      _sortMode = SortMode.date;
    }

    setState(() => _isLoading = true);

    List<AssetEntity> assetList = [];
    final albumNameMap = <String, String>{};

    if (albumManager.selectedAlbumName == albumManager.baseFolderName) {
      final seenIds = <String>{};
      for (final album in albumManager.albums) {
        final assets = await album.getAssetListPaged(page: 0, size: 1000);
        for (final asset in assets) {
          if (seenIds.add(asset.id)) {
            assetList.add(asset);
            albumNameMap[asset.id] = album.name;
          }
        }
      }

      if (albumManager.albums.isEmpty && selectedAlbum != null) {
        final assets = await selectedAlbum.getAssetListPaged(
          page: 0,
          size: 1000,
        );
        for (final asset in assets) {
          if (seenIds.add(asset.id)) {
            assetList.add(asset);
            albumNameMap[asset.id] = selectedAlbum.name;
          }
        }
      }
    } else if (selectedAlbum != null) {
      assetList = await selectedAlbum.getAssetListPaged(page: 0, size: 1000);
      for (final asset in assetList) {
        albumNameMap[asset.id] = selectedAlbum.name;
      }
    }

    // Nur Bilder und Videos
    final filteredList = assetList
        .where((a) => a.type == AssetType.image || a.type == AssetType.video)
        .toList();

    // Nach Datum sortieren
    filteredList.sort((a, b) {
      if (_sortMode == SortMode.name) {
        final nameA = _alphabeticalSortKey(a);
        final nameB = _alphabeticalSortKey(b);
        final baseCompare =
            _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        if (baseCompare != 0) return baseCompare;

        final counterA = _extractCounter(_effectiveName(a));
        final counterB = _extractCounter(_effectiveName(b));
        if (counterA != counterB) {
          return _isAscending
              ? counterA.compareTo(counterB)
              : counterB.compareTo(counterA);
        }

        final titleA = _effectiveName(a).toLowerCase();
        final titleB = _effectiveName(b).toLowerCase();
        final fallback =
            _isAscending ? titleA.compareTo(titleB) : titleB.compareTo(titleA);
        if (fallback != 0) return fallback;

        return _isAscending
            ? a.createDateTime.compareTo(b.createDateTime)
            : b.createDateTime.compareTo(a.createDateTime);
      } else {
        return _isAscending
            ? a.createDateTime.compareTo(b.createDateTime)
            : b.createDateTime.compareTo(a.createDateTime);
      }
    });

    setState(() {
      _photos = filteredList;
      _applyFilter();
      _isLoading = false;
      _assetAlbumNames
        ..clear()
        ..addAll(albumNameMap);
    });

    unawaited(_prefetchDisplayNames(filteredList));
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = List.from(_photos);
    } else {
      _filteredPhotos = _photos.where((asset) {
        final name = _effectiveName(asset).toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  String _alphabeticalSortKey(AssetEntity asset) {
    final title = _effectiveName(asset);
    if (title.isEmpty) return '';
    final tags = _parseTags(title);
    final values = <String>[];

    for (final label in ['B', 'C', 'D', 'E']) {
      final value = tags[label];
      if (value != null && value.isNotEmpty) {
        values.add(value.toLowerCase());
      }
    }

    if (values.isEmpty) {
      final tagA = tags['A'];
      if (tagA != null && tagA.isNotEmpty) {
        final lowerA = tagA.toLowerCase();
        final looksLikeDate = RegExp(r'^\d{6,8}$').hasMatch(lowerA);
        if (!looksLikeDate) {
          values.add(lowerA);
        }
      }
    }

    if (values.isNotEmpty) {
      return values.join('|');
    }

    final baseName = _stripCounter(_stripExtension(title)).toLowerCase();
    final segments = baseName.split(RegExp(r'[-_]')).where((p) => p.isNotEmpty).toList();
    if (segments.length > 1 && RegExp(r'^\d{6,8}$').hasMatch(segments.first)) {
      segments.removeAt(0);
    }
    if (segments.isEmpty) {
      return baseName;
    }
    return segments.join('-');
  }

  String _stripExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  String _effectiveName(AssetEntity asset) {
    return _displayNameOverrides[asset.id] ?? asset.title ?? '';
  }

  Future<void> _prefetchDisplayNames(List<AssetEntity> assets) async {
    if (!Platform.isIOS) return;
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
    final futures = <Future<void>>[];
    for (final asset in assets) {
      if (_displayNameOverrides.containsKey(asset.id)) continue;
      futures.add(albumManager.resolveDisplayName(asset).then((value) {
        _displayNameOverrides[asset.id] = value;
      }));
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _applyFilter();
    });
  }

  String _stripCounter(String name) {
    final match = RegExp(r'^(.*?)([-_]\d{3})$').firstMatch(name);
    return match != null ? match.group(1)! : name;
  }

  int _extractCounter(String? title) {
    if (title == null || title.isEmpty) return -1;
    final nameWithoutExt = _stripExtension(title);
    final match = RegExp(r'[-_](\d{3})$').firstMatch(nameWithoutExt);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? -1;
    }
    return -1;
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
      _applyFilter();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedItems.clear();
    });
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selectedItems.contains(asset)) {
        _selectedItems.remove(asset);
      } else {
        _selectedItems.add(asset);
      }
    });
  }

  Future<bool> _deleteAssetsByIds(List<String> ids) async {
    if (ids.isEmpty) return true;

    if (Platform.isIOS) {
      try {
        final result = await _iosMediaSaverChannel.invokeMethod<bool>(
          'deleteAssets',
          {'assetIds': ids},
        );
        return result ?? false;
      } catch (e) {
        debugPrint('❌ Löschen auf iOS fehlgeschlagen: $e');
        return false;
      }
    } else {
      try {
        final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
        return deletedIds.isNotEmpty;
      } catch (e) {
        debugPrint('❌ Löschen fehlgeschlagen: $e');
        return false;
      }
    }
  }

  void _showDeleteFailedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            de: 'Löschen fehlgeschlagen. Bitte Berechtigungen prüfen.',
            en: 'Deletion failed. Please check your permissions.',
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(de: 'Dateien löschen?', en: 'Delete files?'),
        ),
        content: Text(
          dialogContext.tr(
            de: 'Möchtest du ${_selectedItems.length} Datei(en) wirklich löschen?',
            en: 'Do you really want to delete ${_selectedItems.length} file(s)?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr(de: 'Abbrechen', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr(de: 'Löschen', en: 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = _selectedItems.map((e) => e.id).toList();
      final success = await _deleteAssetsByIds(ids);

      if (!success) {
        _showDeleteFailedMessage();
        return;
      }

      for (final asset in _selectedItems) {
        _displayNameOverrides.remove(asset.id);
      }

      _toggleSelectionMode();
      await _loadCurrentAlbumPhotos();
    }
  }

  Future<void> _deleteSinglePhoto(AssetEntity asset) async {
    final currentName = _effectiveName(asset);
    final resolvedName =
        currentName.isNotEmpty ? currentName : (asset.title ?? '');
    final friendlyName = resolvedName.isEmpty
        ? context.tr(de: 'diese Datei', en: 'this file')
        : resolvedName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(de: 'Datei löschen?', en: 'Delete file?'),
        ),
        content: Text(
          dialogContext.tr(
            de: 'Möchtest du "$friendlyName" wirklich löschen?',
            en: 'Do you really want to delete "$friendlyName"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr(de: 'Abbrechen', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr(de: 'Löschen', en: 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _deleteAssetsByIds([asset.id]);
    if (!success) {
      _showDeleteFailedMessage();
      return;
    }

    _displayNameOverrides.remove(asset.id);
    _selectedItems.remove(asset);

    if (!mounted) return;
    _loadCurrentAlbumPhotos();
  }

  Future<void> _shareSinglePhoto(File file) async {
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              de: '❌ Datei nicht gefunden.',
              en: '❌ File not found.',
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: _shareOriginRect(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              de: '❌ Teilen fehlgeschlagen: $e',
              en: '❌ Share failed: $e',
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _shareSelectedPhotos() async {
    if (_selectedItems.isEmpty) return;

    final files = <XFile>[];
    Directory? shareDir;

    final usedNames = <String>{};

    try {
      final tempDir = await getTemporaryDirectory();
      shareDir = Directory(p.join(tempDir.path, 'share_cache'));
      if (await shareDir.exists()) {
        await shareDir.delete(recursive: true);
      }
      await shareDir.create(recursive: true);

      for (var asset in _selectedItems) {
        final file = await asset.file;
        if (file == null || !await file.exists()) {
          continue;
        }
        var targetName = _shareFilenameForAsset(asset, file);
        targetName = _dedupeShareName(targetName, usedNames);
        final targetPath = p.join(shareDir.path, targetName);
        await File(file.path).copy(targetPath);
        files.add(XFile(targetPath, name: targetName));
      }
    } catch (e) {
      debugPrint('❌ Fehler beim Vorbereiten der Dateien für Teilen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              de: 'Fehler beim Vorbereiten der Dateien: $e',
              en: 'Error preparing files: $e',
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (files.isEmpty) return;

    try {
      final origin = _shareOriginRect();
      await Share.shareXFiles(
        files,
        text: files.length == 1
            ? context.tr(de: 'Datei teilen', en: 'Share file')
            : context.tr(
                de: '${files.length} Dateien teilen',
                en: 'Share ${files.length} files',
              ),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('❌ Fehler beim Teilen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(de: 'Fehler beim Senden: $e', en: 'Error while sharing: $e'),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (shareDir != null) {
        try {
          await shareDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Rect _shareOriginRect() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      return offset & renderBox.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  String _shareFilenameForAsset(AssetEntity asset, File sourceFile) {
    final preferred = _effectiveName(asset);
    final fallback = p.basename(sourceFile.path);
    final selected = preferred.isNotEmpty ? preferred : fallback;
    final sanitized = selected.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
    if (p.extension(sanitized).isEmpty) {
      final ext = p.extension(fallback);
      if (ext.isNotEmpty) {
        return '$sanitized$ext';
      }
    }
    return sanitized;
  }

  String _dedupeShareName(String name, Set<String> used) {
    if (!used.contains(name)) {
      used.add(name);
      return name;
    }
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var counter = 1;
    var candidate = '$base($counter)$ext';
    while (used.contains(candidate)) {
      counter++;
      candidate = '$base($counter)$ext';
    }
    used.add(candidate);
    return candidate;
  }

  Future<void> _renamePhoto(AssetEntity asset) async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
    final file = await asset.file;
    if (file == null || !await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(de: 'Datei nicht gefunden.', en: 'File not found.'),
          ),
        ),
      );
      return;
    }

    final originalName = file.path.split('/').last;
    final effectiveName = _effectiveName(asset);
    final editableSource = effectiveName.isNotEmpty ? effectiveName : originalName;
    final dotIndex = editableSource.lastIndexOf('.');
    String extension = dotIndex >= 0 ? editableSource.substring(dotIndex) : '';
    if (extension.isEmpty) {
      final originalDot = originalName.lastIndexOf('.');
      if (originalDot >= 0) {
        extension = originalName.substring(originalDot);
      }
    }
    final nameWithoutExt =
        dotIndex >= 0 ? editableSource.substring(0, dotIndex) : editableSource;
    final serialMatch = RegExp(r'([-_]\d{3})$').firstMatch(nameWithoutExt);
    final serialSuffix = serialMatch?.group(1) ?? '';
    final editableBase = serialSuffix.isEmpty
        ? nameWithoutExt
        : nameWithoutExt.substring(
            0,
            nameWithoutExt.length - serialSuffix.length,
          );
    final controller = TextEditingController(text: editableBase);
    final fixedSuffix = '$serialSuffix$extension';

    if (!mounted) return;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            dialogContext.tr(de: 'Datei umbenennen', en: 'Rename file'),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: dialogContext.tr(de: 'Neuer Name', en: 'New name'),
              suffixText: fixedSuffix.isEmpty ? null : fixedSuffix,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(dialogContext.tr(de: 'Abbrechen', en: 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final base = controller.text.trim();
                if (base.isEmpty) {
                  Navigator.pop(dialogContext, null);
                  return;
                }
                Navigator.pop(dialogContext, '$base$fixedSuffix');
              },
              child: Text(dialogContext.tr(de: 'Umbenennen', en: 'Rename')),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed == null || confirmed.isEmpty) return;

    if (Platform.isIOS && !_hasShownIosRenameWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            dialogContext.tr(
              de: 'Wichtiger Hinweis',
              en: 'Important notice',
            ),
          ),
          content: Text(
            dialogContext.tr(
              de:
                  'Auf iOS wird die Datei kurzzeitig gelöscht und mit dem neuen Namen wiederhergestellt. Das Betriebssystem kann dabei um Bestätigung für das Löschen bitten. Das ist normal und der Inhalt bleibt erhalten.',
              en:
                  'On iOS the file must be deleted and immediately re-created under the new name. iOS may prompt you to confirm the deletion—this is expected and your media will be restored with the new name.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr(de: 'Abbrechen', en: 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.tr(de: 'Verstanden', en: 'Continue')),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
      _hasShownIosRenameWarning = true;
    }

    final originalAlbumName = _assetAlbumNames[asset.id];

    try {
      String? newAssetId;
      File workingFile;
      String workingPath;
      if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, confirmed);
        workingFile = await File(file.path).copy(tempPath);
        workingPath = tempPath;
      } else {
        final newPath = file.parent.path + Platform.pathSeparator + confirmed;
        workingFile = await file.rename(newPath);
        workingPath = newPath;
      }
      final extension = confirmed.split('.').last.toLowerCase();
      if (Platform.isIOS) {
        final method = (extension == 'mp4' || extension == 'mov' || extension == 'm4v')
            ? 'saveVideo'
            : 'saveImage';
        final createdId =
            await _iosMediaSaverChannel.invokeMethod<String>(method, {
          'path': workingPath,
          'filename': confirmed,
        });
        if (createdId == null || createdId.isEmpty) {
          throw Exception('Failed to create renamed asset on iOS');
        }
        newAssetId = createdId;
        await PhotoManager.editor.deleteWithIds([asset.id]);
        try {
          if (await workingFile.exists()) {
            await workingFile.delete();
          }
        } catch (_) {}
        final cacheId = newAssetId ?? asset.id;
        albumManager.cacheDisplayName(cacheId, confirmed);
        if (newAssetId != null &&
            originalAlbumName != null &&
            originalAlbumName.isNotEmpty) {
          await albumManager.addAssetToDarwinAlbumByName(
            albumName: originalAlbumName,
            assetId: newAssetId,
          );
          _assetAlbumNames.remove(asset.id);
          _assetAlbumNames[newAssetId] = originalAlbumName;
        }
      } else {
        if (extension == 'mp4' || extension == 'mov' || extension == 'm4v') {
          await PhotoManager.editor.saveVideo(workingFile, title: confirmed);
        } else {
          await PhotoManager.editor.saveImageWithPath(workingPath, title: confirmed);
        }
        albumManager.cacheDisplayName(asset.id, confirmed);
      }

      final overrideKey = newAssetId ?? asset.id;
      _displayNameOverrides
        ..remove(asset.id)
        ..[overrideKey] = confirmed;

      if (!mounted) return;
      setState(() {
        _applyFilter();
      });

      _selectedItems.remove(asset);
      if (Platform.isIOS) {
        await albumManager.loadAlbums();
      }
      await _loadCurrentAlbumPhotos();
    } catch (e) {
      debugPrint('❌ Fehler beim Umbenennen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              de: 'Fehler beim Umbenennen: $e',
              en: 'Error while renaming: $e',
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// 🏷️ Extrahiert Tags aus Dateinamen (A-B-C-D-E-F-001.jpg/mp4)
  Map<String, String> _parseTags(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    final nameWithoutExt = dotIndex > 0
        ? filename.substring(0, dotIndex)
        : filename;

    final counterMatch = RegExp(
      r'^(.*?)([-_]\d{3})$',
    ).firstMatch(nameWithoutExt);
    final baseName = counterMatch != null
        ? counterMatch.group(1)!
        : nameWithoutExt;

    if (baseName.isEmpty) return {};

    String separator;
    final dashParts = baseName.split('-');
    final underscoreParts = baseName.split('_');
    if (dashParts.length >= underscoreParts.length && dashParts.length > 1) {
      separator = '-';
    } else if (underscoreParts.length > 1) {
      separator = '_';
    } else {
      separator = '-';
    }

    final parts = baseName.split(separator).where((p) => p.isNotEmpty).toList();
    final tags = <String, String>{};
    const labels = ['A', 'B', 'C', 'D', 'E'];

    for (var i = 0; i < parts.length && i < labels.length; i++) {
      tags[labels[i]] = parts[i];
    }

    return tags;
  }

  Future<void> _showAlbumSelectionDialog() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
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
                  dialogContext.tr(
                    de: 'Album auswählen',
                    en: 'Choose album',
                  ),
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
                  leading: const Icon(Icons.folder_special_outlined),
                  title: Text(
                    dialogContext.tr(de: 'Alle Dateien', en: 'All files'),
                  ),
                  trailing:
                      albumManager.selectedAlbumName ==
                          albumManager.baseFolderName
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectDefaultAlbum();
                    Navigator.pop(dialogContext);
                    _loadCurrentAlbumPhotos();
                  },
                ),
                const Divider(),
                if (albumManager.albums
                    .where(
                      (album) =>
                          album.name != albumManager.baseFolderName &&
                          album.name.toLowerCase() != 'recents',
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
                        if (album.name == albumManager.baseFolderName) {
                          return false;
                        }
                        if (album.name.toLowerCase() == 'recents') {
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
                            _loadCurrentAlbumPhotos();
                          },
                        );
                      }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionProvider>();
    final isPremium = subscription.isPremium;

    if (!isPremium) {
      if (_sortMode == SortMode.name) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _sortMode = SortMode.date;
          });
          _loadCurrentAlbumPhotos();
        });
      }
      if (_searchQuery.isNotEmpty || _searchController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _searchController.clear();
        });
      }
    }

    final albumManager = Provider.of<AlbumManager>(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showAlbumOrigin =
        albumManager.selectedAlbumName == albumManager.baseFolderName;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C281D) : scheme.primary,
        foregroundColor: isDark ? scheme.onSurface : scheme.onPrimary,
        title: _selectionMode
            ? Text(
                _selectedItems.isEmpty
                    ? context.tr(de: 'Keine Auswahl', en: 'No selection')
                    : context.tr(
                        de: '${_selectedItems.length} ausgewählt',
                        en: '${_selectedItems.length} selected',
                      ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : GestureDetector(
                onTap: _showAlbumSelectionDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF273429)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          () {
                            final mgr = Provider.of<AlbumManager>(
                              context,
                              listen: false,
                            );
                            return mgr.selectedAlbumName == mgr.baseFolderName
                                ? context.tr(
                                    de: 'Alle Dateien',
                                    en: 'All files',
                                  )
                                : mgr.selectedAlbumName;
                          }(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? scheme.onSurface : Colors.white,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? scheme.onSurface : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
        centerTitle: true,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedItems.length == _filteredPhotos.length
                    ? Icons.indeterminate_check_box
                    : Icons.select_all,
              ),
              tooltip: _selectedItems.length == _filteredPhotos.length
                  ? context.tr(de: 'Auswahl aufheben', en: 'Clear selection')
                  : context.tr(de: 'Alle auswählen', en: 'Select all'),
              onPressed: () {
                setState(() {
                  if (_selectedItems.length == _filteredPhotos.length) {
                    _selectedItems.clear();
                  } else {
                    _selectedItems = _filteredPhotos.toSet();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: context.tr(de: 'Löschen', en: 'Delete'),
              onPressed: _selectedItems.isEmpty ? null : _deleteSelectedPhotos,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: context.tr(de: 'Senden / Teilen', en: 'Share'),
              onPressed: _selectedItems.isEmpty ? null : _shareSelectedPhotos,
            ),
          ],
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box),
            tooltip: _selectionMode
                ? context.tr(
                    de: 'Auswahlmodus beenden',
                    en: 'Exit selection mode',
                  )
                : context.tr(
                    de: 'Auswahlmodus starten',
                    en: 'Enter selection mode',
                  ),
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔎 Suchfeld + Sortierbutton
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                PopupMenuButton<SortMode>(
                  icon: const Icon(Icons.sort),
                  tooltip: context.tr(
                    de: 'Sortieren nach...',
                    en: 'Sort by...',
                  ),
                  onSelected: (mode) {
                    if (!isPremium && mode == SortMode.name) {
                      _showPremiumPrompt();
                      return;
                    }
                    setState(() => _sortMode = mode);
                    _loadCurrentAlbumPhotos();
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<SortMode>(
                      value: SortMode.date,
                      checked: _sortMode == SortMode.date,
                      child: Text(
                        context.tr(
                          de: 'Nach Datum sortieren',
                          en: 'Sort by date',
                        ),
                      ),
                    ),
                    CheckedPopupMenuItem<SortMode>(
                      value: SortMode.name,
                      checked: _sortMode == SortMode.name,
                      enabled: isPremium,
                      child: Row(
                        children: [
                          Text(
                            context.tr(
                              de: 'Alphabetisch sortieren',
                              en: 'Sort alphabetically',
                            ),
                          ),
                          if (!isPremium) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.lock_outline, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  tooltip: _isAscending
                      ? context.tr(
                          de: 'Aufsteigend sortieren',
                          en: 'Sort ascending',
                        )
                      : context.tr(
                          de: 'Absteigend sortieren',
                          en: 'Sort descending',
                        ),
                  onPressed: () {
                    setState(() => _isAscending = !_isAscending);
                    _loadCurrentAlbumPhotos();
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TextField(
                        controller: _searchController,
                        enabled: isPremium,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            de: 'Suche...',
                            en: 'Search...',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: context.tr(
                                    de: 'Suche löschen',
                                    en: 'Clear search',
                                  ),
                                  onPressed: () => _searchController.clear(),
                                ),
                          filled: true,
                          fillColor: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? const Color(0xFF273429)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      if (!isPremium)
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _showPremiumPrompt,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📸 Medienliste
          Expanded(
            child: _filteredPhotos.isEmpty
                ? Center(
                    child: Text(
                      context.tr(
                        de: 'Keine Medien gefunden.',
                        en: 'No media found.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredPhotos.length,
                    itemBuilder: (context, index) {
                      final asset = _filteredPhotos[index];
                      final isSelected = _selectedItems.contains(asset);

                      return FutureBuilder<File?>(
                        future: asset.file,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(height: 100);
                          }

                          final file = snapshot.data!;
                          final displayName = _effectiveName(asset);

                          return InkWell(
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelect(asset);
                              } else {
                                if (asset.type == AssetType.video) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoPlayerPage(
                                        videoFile: file,
                                        displayName: displayName,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FullscreenImagePage(
                                        imageFile: file,
                                        displayName: displayName,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            onLongPress: () {
                              if (!_selectionMode) {
                                setState(() {
                                  _selectionMode = true;
                                  _selectedItems = {asset};
                                });
                              } else {
                                _toggleSelect(asset);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectionMode && isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.16)
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF1B241C)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: _selectionMode && isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: asset.type == AssetType.video
                                                ? Stack(
                                                    children: [
                                                      FutureBuilder<Uint8List?>(
                                                        future:
                                                            asset.thumbnailData,
                                                        builder:
                                                            (context, snapshot) {
                                                          if (!snapshot
                                                              .hasData) {
                                                            return Container(
                                                              width: 82,
                                                              height: 82,
                                                              color: Colors.grey
                                                                  .shade300,
                                                              child:
                                                                  const Center(
                                                                child: Icon(
                                                                  Icons.videocam,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                          return Image.memory(
                                                            snapshot.data!,
                                                            width: 82,
                                                            height: 82,
                                                            fit: BoxFit.cover,
                                                          );
                                                        },
                                                      ),
                                                      Positioned(
                                                        bottom: 6,
                                                        right: 6,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.black
                                                                .withValues(
                                                                    alpha: 0.5),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              12,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: const [
                                                              Icon(
                                                                Icons
                                                                    .play_arrow_rounded,
                                                                size: 16,
                                                                color:
                                                                    Colors.white,
                                                              ),
                                                              SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                'Video',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Image.file(
                                                    file,
                                                    width: 82,
                                                    height: 82,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          if (_selectionMode)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isSelected
                                                    ? Colors.lightGreen
                                                    : Colors.white70,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      if (!_selectionMode)
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  side: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                label: Text(
                                                  context.tr(
                                                    de: 'Umbenennen',
                                                    en: 'Rename',
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _renamePhoto(asset),
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  side: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                                icon: const Icon(Icons.delete,
                                                    size: 18),
                                                label: Text(
                                                  context.tr(
                                                    de: 'Löschen',
                                                    en: 'Delete',
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _deleteSinglePhoto(asset),
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  side: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                                icon: Icon(
                                                  Theme.of(context)
                                                              .platform ==
                                                          TargetPlatform.iOS
                                                      ? Icons.ios_share
                                                      : Icons.share,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  context.tr(
                                                    de: 'Teilen',
                                                    en: 'Share',
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _shareSinglePhoto(file),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

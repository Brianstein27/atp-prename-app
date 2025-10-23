import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../utils/album_manager.dart';
import 'fullscreen_image_page.dart';
import 'video_player_page.dart';
import 'package:share_plus/share_plus.dart';

enum SortMode { date, name }

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  SortMode _sortMode = SortMode.date;
  List<AssetEntity> _photos = [];
  List<AssetEntity> _filteredPhotos = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  bool _isAscending = false;
  String _searchQuery = '';
  Set<AssetEntity> _selectedItems = {};
  late final TextEditingController _searchController;

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

    setState(() => _isLoading = true);

    List<AssetEntity> assetList = [];

    if (albumManager.selectedAlbumName == albumManager.baseFolderName) {
      final seenIds = <String>{};
      for (final album in albumManager.albums) {
        final assets = await album.getAssetListPaged(page: 0, size: 1000);
        for (final asset in assets) {
          if (seenIds.add(asset.id)) {
            assetList.add(asset);
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
          }
        }
      }
    } else if (selectedAlbum != null) {
      assetList = await selectedAlbum.getAssetListPaged(page: 0, size: 1000);
    }

    // Nur Bilder und Videos
    final filteredList = assetList
        .where((a) => a.type == AssetType.image || a.type == AssetType.video)
        .toList();

    // Nach Datum sortieren
    filteredList.sort((a, b) {
      if (_sortMode == SortMode.name) {
        final nameA = (a.title ?? '').toLowerCase();
        final nameB = (b.title ?? '').toLowerCase();
        return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
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
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = List.from(_photos);
    } else {
      _filteredPhotos = _photos.where((asset) {
        final name = asset.title?.toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }
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

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dateien löschen?'),
        content: Text(
          'Möchtest du ${_selectedItems.length} Datei(en) wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var asset in _selectedItems) {
        await PhotoManager.editor.deleteWithIds([asset.id]);
      }
      _toggleSelectionMode();
      _loadCurrentAlbumPhotos();
    }
  }

  Future<void> _shareSelectedPhotos() async {
    if (_selectedItems.isEmpty) return;

    final files = <XFile>[];

    for (var asset in _selectedItems) {
      final file = await asset.file;
      if (file != null && await file.exists()) {
        files.add(XFile(file.path));
      }
    }

    if (files.isEmpty) return;

    try {
      await Share.shareXFiles(
        files,
        text: files.length == 1
            ? 'Datei teilen'
            : '${files.length} Dateien teilen',
      );
    } catch (e) {
      debugPrint('❌ Fehler beim Teilen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Senden: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _renamePhoto(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !await file.exists()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Datei nicht gefunden.')));
      return;
    }

    final oldName = file.path.split('/').last;
    final dotIndex = oldName.lastIndexOf('.');
    final extension = dotIndex >= 0 ? oldName.substring(dotIndex) : '';
    final nameWithoutExt =
        dotIndex >= 0 ? oldName.substring(0, dotIndex) : oldName;
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

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Datei umbenennen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Neuer Name',
              suffixText: fixedSuffix.isEmpty ? null : fixedSuffix,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final base = controller.text.trim();
                if (base.isEmpty) {
                  Navigator.pop(context, null);
                  return;
                }
                Navigator.pop(context, '$base$fixedSuffix');
              },
              child: const Text('Umbenennen'),
            ),
          ],
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty) return;

    final newPath = file.parent.path + Platform.pathSeparator + confirmed;

    try {
      await file.rename(newPath);
      final extension = confirmed.split('.').last.toLowerCase();
      if (extension == 'mp4' || extension == 'mov' || extension == 'm4v') {
        await PhotoManager.editor.saveVideo(File(newPath), title: confirmed);
      } else {
        await PhotoManager.editor.saveImageWithPath(newPath, title: confirmed);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datei umbenannt in "$confirmed"')),
      );

      _loadCurrentAlbumPhotos();
    } catch (e) {
      debugPrint('❌ Fehler beim Umbenennen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Umbenennen: $e'),
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
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

    for (var i = 0; i < parts.length && i < labels.length; i++) {
      tags[labels[i]] = parts[i];
    }

    return tags;
  }

  Future<void> _showAlbumSelectionDialog() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);
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
                  leading: const Icon(Icons.folder_special_outlined),
                  title: const Text('Alle Dateien'),
                  trailing:
                      albumManager.selectedAlbumName ==
                          albumManager.baseFolderName
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectDefaultAlbum();
                    Navigator.pop(context);
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
                      'Noch keine weiteren Alben vorhanden.',
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
                              return Text('$count Elemente');
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
                            _loadCurrentAlbumPhotos();
                          },
                        );
                      })
                      .toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumManager = Provider.of<AlbumManager>(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    ? 'Keine Auswahl'
                    : '${_selectedItems.length} ausgewählt',
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
                        : Colors.white.withOpacity(0.15),
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
                                ? 'Alle Dateien'
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
                  ? 'Auswahl aufheben'
                  : 'Alle auswählen',
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
              tooltip: 'Löschen',
              onPressed: _selectedItems.isEmpty ? null : _deleteSelectedPhotos,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Senden / Teilen',
              onPressed: _selectedItems.isEmpty ? null : _shareSelectedPhotos,
            ),
          ],
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box),
            tooltip: _selectionMode
                ? 'Auswahlmodus beenden'
                : 'Auswahlmodus starten',
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
                  tooltip: 'Sortieren nach...',
                  onSelected: (mode) {
                    setState(() => _sortMode = mode);
                    _loadCurrentAlbumPhotos();
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<SortMode>(
                      value: SortMode.date,
                      checked: _sortMode == SortMode.date,
                      child: const Text('Nach Datum sortieren'),
                    ),
                    CheckedPopupMenuItem<SortMode>(
                      value: SortMode.name,
                      checked: _sortMode == SortMode.name,
                      child: const Text('Alphabetisch sortieren'),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  tooltip: _isAscending
                      ? 'Aufsteigend sortieren'
                      : 'Absteigend sortieren',
                  onPressed: () {
                    setState(() => _isAscending = !_isAscending);
                    _loadCurrentAlbumPhotos();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Suche...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Suche löschen',
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
                              .withOpacity(0.5),
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📸 Medienliste
          Expanded(
            child: _filteredPhotos.isEmpty
                ? const Center(child: Text('Keine Medien gefunden.'))
                : ListView.builder(
                    itemCount: _filteredPhotos.length,
                    itemBuilder: (context, index) {
                      final asset = _filteredPhotos[index];
                      final isSelected = _selectedItems.contains(asset);

                      return FutureBuilder<File?>(
                        future: asset.file,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(height: 80);
                          }

                          final file = snapshot.data!;
                          final tags = _parseTags(file.path.split('/').last);

                          return InkWell(
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelect(asset);
                              } else {
                                if (asset.type == AssetType.video) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VideoPlayerPage(videoFile: file),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FullscreenImagePage(imageFile: file),
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
                              decoration: BoxDecoration(
                                color: _selectionMode && isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2)
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF1B241C)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectionMode && isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withOpacity(0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: asset.type == AssetType.video
                                          ? Stack(
                                              children: [
                                                FutureBuilder<Uint8List?>(
                                                  future: asset.thumbnailData,
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData) {
                                                      return Container(
                                                        width: 90,
                                                        height: 90,
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.videocam,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    return Image.memory(
                                                      snapshot.data!,
                                                      width: 90,
                                                      height: 90,
                                                      fit: BoxFit.cover,
                                                    );
                                                  },
                                                ),
                                                const Positioned(
                                                  bottom: 4,
                                                  right: 4,
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Image.file(
                                              file,
                                              width: 90,
                                              height: 90,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    if (_selectionMode)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? Colors.lightGreen
                                              : Colors.white70,
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  file.path.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  tags.entries
                                      .map((e) => '${e.key}: ${e.value}')
                                      .join('   '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: !_selectionMode
                                    ? PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'rename')
                                            _renamePhoto(asset);
                                          if (value == 'delete')
                                            _deleteSelectedPhotos();
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'rename',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text('Umbenennen'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 18),
                                                SizedBox(width: 8),
                                                Text('Löschen'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
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

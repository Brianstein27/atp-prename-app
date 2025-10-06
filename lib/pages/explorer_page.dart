import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../utils/album_manager.dart';
import './fullscreen_image_page.dart';
import 'package:share_plus/share_plus.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  List<AssetEntity> _photos = [];
  List<AssetEntity> _filteredPhotos = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  Set<AssetEntity> _selectedItems = {};
  bool _isAscending = false; // false = Neueste zuerst (Standard)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentAlbumPhotos();
  }

  // ---------------------------------------------------------------
  //  Fotos laden (mit Sortierung)
  // ---------------------------------------------------------------
  Future<void> _loadCurrentAlbumPhotos() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
    }

    final selectedAlbum = albumManager.selectedAlbum;
    if (selectedAlbum == null) {
      setState(() {
        _photos = [];
        _filteredPhotos = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final assetList = await selectedAlbum.getAssetListPaged(
      page: 0,
      size: 1000,
    );

    // Sortieren nach Datum
    assetList.sort((a, b) {
      if (_isAscending) {
        return a.createDateTime.compareTo(b.createDateTime);
      } else {
        return b.createDateTime.compareTo(a.createDateTime);
      }
    });

    setState(() {
      _photos = assetList;
      _applySearchFilter();
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------
  //  Filter anwenden (Suche)
  // ---------------------------------------------------------------
  void _applySearchFilter() async {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() => _filteredPhotos = List.from(_photos));
      return;
    }

    final filtered = <AssetEntity>[];

    for (var asset in _photos) {
      final file = await asset.file;
      if (file == null) continue;

      final filename = file.path.split('/').last.toLowerCase();
      final tags = _parseTags(filename).values.join('-').toLowerCase();

      if (filename.contains(query) || tags.contains(query)) {
        filtered.add(asset);
      }
    }

    setState(() => _filteredPhotos = filtered);
  }

  // ---------------------------------------------------------------
  //  Löschen
  // ---------------------------------------------------------------
  Future<void> _deleteSelectedPhotos() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotos löschen?'),
        content: Text(
          'Möchtest du ${_selectedItems.length} Foto(s) wirklich löschen?',
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

  // ---------------------------------------------------------------
  //  Teilen
  // ---------------------------------------------------------------
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
            ? 'Foto teilen'
            : '${files.length} Fotos teilen',
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

  // ---------------------------------------------------------------
  //  Fotos Umbenennen
  // ---------------------------------------------------------------

  Future<void> _renamePhoto(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !await file.exists()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Datei nicht gefunden.')));
      return;
    }

    final oldName = file.path.split('/').last;
    final controller = TextEditingController(text: oldName);

    // 📋 Dialog für Eingabe des neuen Namens
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Foto umbenennen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Neuer Dateiname (mit .jpg)',
            ),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Umbenennen'),
            ),
          ],
        );
      },
    );

    if (confirmed == null || confirmed.isEmpty) return;

    // 🔤 Validierung
    if (!confirmed.toLowerCase().endsWith('.jpg')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Dateiname muss auf ".jpg" enden.')),
      );
      return;
    }

    final newPath = file.parent.path + Platform.pathSeparator + confirmed;

    try {
      await file.rename(newPath);
      await PhotoManager.editor.saveImageWithPath(newPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datei umbenannt in "$confirmed"')),
      );

      _loadCurrentAlbumPhotos();
    } catch (e) {
      debugPrint('Fehler beim Umbenennen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Umbenennen: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ---------------------------------------------------------------
  //  Auswahlmodus umschalten
  // ---------------------------------------------------------------
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedItems.clear();
    });
  }

  // ---------------------------------------------------------------
  //  Auswahl einzelner Fotos togglen
  // ---------------------------------------------------------------
  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selectedItems.contains(asset)) {
        _selectedItems.remove(asset);
      } else {
        _selectedItems.add(asset);
      }
    });
  }

  // ---------------------------------------------------------------
  //  Albumauswahl
  // ---------------------------------------------------------------
  Future<void> _showAlbumSelectionDialog() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
      if (!albumManager.hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Zugriff verweigert. Bitte Berechtigung erteilen.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    }

    await albumManager.loadAlbums();

    if (albumManager.albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Keine Alben gefunden.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
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
                return ListTile(
                  title: Text(album.name),
                  subtitle: FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) {
                      return Text('${snapshot.data ?? 0} Medien');
                    },
                  ),
                  trailing: albumManager.selectedAlbum?.id == album.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    albumManager.selectAlbum(album);
                    Navigator.pop(context);
                    _loadCurrentAlbumPhotos();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  //  Tag Parsing
  // ---------------------------------------------------------------
  Map<String, String> _parseTags(String filename) {
    final nameWithoutExt = filename.split('.').first;
    final parts = nameWithoutExt.split('-');
    final tags = <String, String>{};

    if (parts.isNotEmpty) tags['A'] = parts[0];
    if (parts.length > 1) tags['B'] = parts[1];
    if (parts.length > 2) tags['C'] = parts[2];
    if (parts.length > 3) tags['D'] = parts[3];
    if (parts.length > 4) tags['E'] = parts[4];

    return tags;
  }

  // ---------------------------------------------------------------
  //  Einzelner Eintrag (ListTile)
  // ---------------------------------------------------------------
  Widget _buildPhotoTile(AssetEntity asset) {
    final isSelected = _selectedItems.contains(asset);

    return FutureBuilder<File?>(
      future: asset.file,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 80);
        final file = snapshot.data!;
        final tags = _parseTags(file.path.split('/').last);

        return ListTile(
          onLongPress: () => _renamePhoto(asset),
          leading: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_selectionMode) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FullscreenImagePage(imageFile: file),
                      ),
                    );
                  } else {
                    _toggleSelect(asset);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
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
                    color: isSelected ? Colors.lightGreen : Colors.white70,
                  ),
                ),
            ],
          ),
          title: Text(
            file.path.split('/').last,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            tags.entries.map((e) => '${e.key}: ${e.value}').join('   '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _renamePhoto(asset);
              if (value == 'delete') _deleteSelectedPhotos();
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
          ),
          onTap: _selectionMode ? () => _toggleSelect(asset) : null,
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final albumManager = Provider.of<AlbumManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightGreen.shade700,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onTap: _showAlbumSelectionDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  albumManager.selectedAlbumName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Löschen',
              onPressed: _deleteSelectedPhotos,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Senden / Teilen',
              onPressed: _shareSelectedPhotos,
            ),
          ],
          IconButton(
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box),
            tooltip: 'Auswahlmodus umschalten',
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔍 Suchleiste & Sortierbutton
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Colors.lightGreen.shade700,
                  ),
                  tooltip: _isAscending
                      ? 'Nach ältesten zuerst sortieren'
                      : 'Nach neuesten zuerst sortieren',
                  onPressed: () {
                    setState(() => _isAscending = !_isAscending);
                    _loadCurrentAlbumPhotos();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchQuery = value;
                      _applySearchFilter();
                    },
                    decoration: InputDecoration(
                      hintText: 'Suche nach Dateiname oder Tags...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _applySearchFilter();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📷 Foto-Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPhotos.isEmpty
                ? const Center(child: Text('Keine passenden Fotos gefunden.'))
                : ListView.builder(
                    itemCount: _filteredPhotos.length,
                    itemBuilder: (context, index) =>
                        _buildPhotoTile(_filteredPhotos[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

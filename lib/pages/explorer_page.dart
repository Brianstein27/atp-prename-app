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
  bool _isLoading = true;
  bool _selectionMode = false;
  Set<AssetEntity> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentAlbumPhotos();
  }

  Future<void> _loadCurrentAlbumPhotos() async {
    final albumManager = Provider.of<AlbumManager>(context, listen: false);

    if (!albumManager.hasPermission) {
      await albumManager.loadAlbums();
    }

    final selectedAlbum = albumManager.selectedAlbum;
    if (selectedAlbum == null) {
      setState(() {
        _photos = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final assetList = await selectedAlbum.getAssetListPaged(
      page: 0,
      size: 1000,
    );

    setState(() {
      _photos = assetList;
      _isLoading = false;
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

  // ✅ 1️⃣ TEILEN-METHODE
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

  // ✅ 2️⃣ LÖSCHEN-METHODE
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

  /// Albumauswahl-Dialog
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

  @override
  Widget build(BuildContext context) {
    final albumManager = Provider.of<AlbumManager>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${albumManager.selectedAlbumName}'),
        backgroundColor: Colors.lightGreen.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_album),
            tooltip: 'Album wechseln',
            onPressed: _showAlbumSelectionDialog,
          ),
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
      body: _photos.isEmpty
          ? const Center(child: Text('Keine Fotos im ausgewählten Album.'))
          : ListView.builder(
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final asset = _photos[index];
                final isSelected = _selectedItems.contains(asset);

                return FutureBuilder<File?>(
                  future: asset.file,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 80);
                    }

                    final file = snapshot.data!;
                    final tags = _parseTags(file.path.split('/').last);

                    return ListTile(
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
                      onTap: _selectionMode ? () => _toggleSelect(asset) : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Basisordner innerhalb von DCIM, unter dem alle App-Alben liegen.
const String _baseFolderName = 'Prename-App';
const String _defaultAlbumName = _baseFolderName;
const String _managedAlbumsPrefsKey = 'managed_album_names';

class AlbumManager extends ChangeNotifier {
  // --- STATE ---
  AssetPathEntity? _selectedAlbum;
  String _selectedAlbumName = _defaultAlbumName;
  List<AssetPathEntity> _albums = [];
  int _currentFileCounter = 1;
  bool _hasPermission = false;
  final List<String> _managedAlbumNames = [];
  bool _managedAlbumsLoaded = false;

  // --- Getter ---
  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  String get selectedAlbumName => _selectedAlbumName;
  List<AssetPathEntity> get albums => _albums;
  int get currentFileCounter => _currentFileCounter;
  bool get hasPermission => _hasPermission;
  String get baseFolderName => _baseFolderName;
  String get defaultAlbumName => _defaultAlbumName;
  String get displayNameBaseFolder => 'Kein Album ausgewählt';

  // --- Platform Channel für MediaScan (nur als Fallback) ---
  static const _channel = MethodChannel(
    'com.example.atp_prename_app/media_scan',
  );

  Future<void> _ensureManagedAlbumsLoaded() async {
    if (_managedAlbumsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_managedAlbumsPrefsKey) ?? const [];
    _managedAlbumNames
      ..clear()
      ..addAll(stored);
    _managedAlbumsLoaded = true;
  }

  Future<void> _persistManagedAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_managedAlbumsPrefsKey, _managedAlbumNames);
  }

  String _buildRelativePath() {
    final segments = ['DCIM', _baseFolderName];
    if (_selectedAlbumName.isNotEmpty &&
        _selectedAlbumName != _defaultAlbumName) {
      segments.add(_selectedAlbumName);
    }
    return segments.join('/');
  }

  // --- ALBEN LADEN ---
  Future<void> loadAlbums() async {
    await _ensureManagedAlbumsLoaded();

    final status = await PhotoManager.requestPermissionExtend();
    if (!status.isAuth) {
      _hasPermission = false;
      _albums = [];
      notifyListeners();
      return;
    }

    _hasPermission = true;

    final allAlbums = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.common, // images + videos
    );

    final filtered = <AssetPathEntity>[
      for (final album in allAlbums)
        if (album.name == _defaultAlbumName ||
            _managedAlbumNames.contains(album.name))
          album,
    ];

    _albums = filtered;

    AssetPathEntity? match;
    try {
      match = _albums.firstWhere((a) => a.name == _selectedAlbumName);
    } catch (_) {
      try {
        match = _albums.firstWhere((a) => a.name == _defaultAlbumName);
        _selectedAlbumName = match.name;
      } catch (_) {
        match = null;
        _selectedAlbumName = _defaultAlbumName;
      }
    }

    _selectedAlbum = match;

    notifyListeners();
  }

  // --- ALBUM AUSWÄHLEN ---
  void selectAlbum(AssetPathEntity album) {
    _selectedAlbum = album;
    _selectedAlbumName = album.name;
    getNextFileCounter();
    notifyListeners();
  }

  void selectDefaultAlbum() {
    try {
      _selectedAlbum = _albums.firstWhere((a) => a.name == _defaultAlbumName);
    } catch (_) {
      _selectedAlbum = null;
    }
    _selectedAlbumName = _defaultAlbumName;
    getNextFileCounter();
    notifyListeners();
  }

  // --- ALBUM ERSTELLEN ---
  Future<void> createAlbum(String name) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return;

    await loadAlbums();
    await _ensureManagedAlbumsLoaded();

    final exists = _albums.any((a) => a.name == cleanedName);

    if (exists) {
      _selectedAlbum = _albums.firstWhere((a) => a.name == cleanedName);
    } else {
      _selectedAlbum = null; // Ordner wird beim Speichern angelegt
    }

    _selectedAlbumName = cleanedName;

    if (cleanedName != _defaultAlbumName &&
        !_managedAlbumNames.contains(cleanedName)) {
      _managedAlbumNames.add(cleanedName);
      await _persistManagedAlbums();
    }

    _currentFileCounter = 1;
    notifyListeners();
  }

  // --- BILD SPEICHERN (Scoped Storage konform) ---
  Future<void> saveImage(File imageFile, String filename) async {
    try {
      if (!_hasPermission) await loadAlbums();

      final relativePath = _buildRelativePath();
      final asset = await PhotoManager.editor.saveImageWithPath(
        imageFile.path,
        title: filename,
        relativePath: relativePath,
      );

      if (asset == null) {
        debugPrint('❌ Fehler beim Speichern des Bildes: asset == null');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
      await loadAlbums();

      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        debugPrint('⚠️ Album "${_selectedAlbumName}" nicht gefunden.');
      }

      await getNextFileCounter();
      debugPrint('✅ Bild gespeichert in $relativePath/$filename');
    } catch (e) {
      debugPrint('❌ Fehler beim Speichern des Bildes: $e');
    }
  }

  // --- VIDEO SPEICHERN (Scoped-Storage-konform + Zielalbum) ---
  Future<void> saveVideo(File videoFile, String filename) async {
    try {
      if (!_hasPermission) {
        await loadAlbums();
        if (!_hasPermission) {
          debugPrint('❌ Keine Berechtigung zum Speichern von Videos.');
          return;
        }
      }

      final relativePath = _buildRelativePath();

      debugPrint('🎬 Video wird gespeichert in "$relativePath": $filename');

      final asset = await PhotoManager.editor.saveVideo(
        videoFile,
        title: filename,
        relativePath: relativePath,
      );

      if (asset == null) {
        debugPrint(
          '❌ Fehler: asset == null – Video konnte nicht gespeichert werden',
        );
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
      await loadAlbums();

      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        debugPrint('⚠️ Album "$_selectedAlbumName" noch nicht gefunden.');
      }

      await getNextFileCounter();
      debugPrint('✅ Video gespeichert unter $relativePath/$filename');
    } catch (e) {
      debugPrint('❌ Fehler beim Speichern des Videos: $e');
    }
  }

  // --- NÄCHSTEN FREIEN ZÄHLER FÜR TAGS ERMITTELN ---
  Future<int> getNextAvailableCounterForTags(
    List<String> parts, {
    required String separator,
  }) async {
    if (parts.isEmpty) {
      return _currentFileCounter;
    }

    try {
      final lowerBase = parts.join(separator).toLowerCase();
      int highest = 0;

      Future<void> inspectAssets(AssetPathEntity path) async {
        final assets = await path.getAssetListPaged(page: 0, size: 1000);
        for (final asset in assets) {
          final title = asset.title?.toLowerCase() ?? '';
          if (title.startsWith(lowerBase)) {
            final match = RegExp(r'(\d{3})(?=\.\w+$)').firstMatch(title);
            if (match != null) {
              final num = int.tryParse(match.group(1) ?? '') ?? 0;
              if (num > highest) highest = num;
            }
          }
        }
      }

      ;

      if (_selectedAlbumName == _defaultAlbumName) {
        for (final album in _albums) {
          await inspectAssets(album);
        }
      } else if (_selectedAlbum != null) {
        await inspectAssets(_selectedAlbum!);
      }

      return highest + 1;
    } catch (e) {
      debugPrint('⚠️ Fehler bei getNextAvailableCounterForTags: $e');
      return 1;
    }
  }

  // --- STANDARD-ZÄHLER AKTUALISIEREN ---
  Future<void> getNextFileCounter() async {
    try {
      if (_selectedAlbumName == _defaultAlbumName) {
        int total = 0;
        for (final album in _albums) {
          final assets = await album.getAssetListPaged(page: 0, size: 1000);
          total += assets.length;
        }
        _currentFileCounter = total + 1;
      } else if (_selectedAlbum != null) {
        final assets = await _selectedAlbum!.getAssetListPaged(
          page: 0,
          size: 1000,
        );
        _currentFileCounter = assets.length + 1;
      } else {
        _currentFileCounter = 1;
      }
    } catch (_) {
      _currentFileCounter = 1;
    }
    notifyListeners();
  }
}

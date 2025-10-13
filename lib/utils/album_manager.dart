import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// Standard-Albumname, falls keines ausgewählt ist.
const String _defaultAlbumName = 'Pictures';

class AlbumManager extends ChangeNotifier {
  // --- STATE ---
  AssetPathEntity? _selectedAlbum;
  String _selectedAlbumName = _defaultAlbumName;
  List<AssetPathEntity> _albums = [];
  int _currentFileCounter = 1;
  bool _hasPermission = false;

  // --- Getter ---
  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  String get selectedAlbumName => _selectedAlbumName;
  List<AssetPathEntity> get albums => _albums;
  int get currentFileCounter => _currentFileCounter;
  bool get hasPermission => _hasPermission;

  // --- Platform Channel für MediaScan (nur als Fallback) ---
  static const _channel = MethodChannel(
    'com.example.atp_prename_app/media_scan',
  );

  // --- ALBEN LADEN ---
  Future<void> loadAlbums() async {
    final status = await PhotoManager.requestPermissionExtend();
    if (!status.isAuth) {
      _hasPermission = false;
      _albums = [];
      notifyListeners();
      return;
    }

    _hasPermission = true;

    _albums = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.common, // images + videos
    );

    // Falls noch kein Album gewählt ist → "Pictures"
    if (_selectedAlbum == null && _albums.isNotEmpty) {
      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        _selectedAlbum = _albums.first;
        _selectedAlbumName = _selectedAlbum!.name;
      }
    }

    notifyListeners();
  }

  // --- ALBUM AUSWÄHLEN ---
  void selectAlbum(AssetPathEntity album) {
    _selectedAlbum = album;
    _selectedAlbumName = album.name;
    getNextFileCounter();
    notifyListeners();
  }

  // --- ALBUM ERSTELLEN ---
  Future<void> createAlbum(String name) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return;

    await loadAlbums();
    final exists = _albums.any((a) => a.name == cleanedName);

    if (exists) {
      _selectedAlbum = _albums.firstWhere((a) => a.name == cleanedName);
    } else {
      // Album wird automatisch bei erstem Speichern angelegt
      _selectedAlbum = null;
    }

    _selectedAlbumName = cleanedName;
    _currentFileCounter = 1;
    notifyListeners();
  }

  // --- BILD SPEICHERN (Scoped Storage konform) ---
  Future<void> saveImage(File imageFile, String filename) async {
    try {
      if (!_hasPermission) await loadAlbums();

      final relativePath = 'DCIM/$_selectedAlbumName';
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
        final found = _albums.firstWhere((a) => a.name == _selectedAlbumName);
        _selectedAlbum = found;
      } catch (_) {
        debugPrint('⚠️ Album "${_selectedAlbumName}" nicht gefunden.');
      }

      await getNextFileCounter();
      debugPrint('✅ Bild gespeichert in $_selectedAlbumName/$filename');
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

      debugPrint(
        '🎬 Video wird gespeichert in Album "$_selectedAlbumName": $filename',
      );

      // 1️⃣ Systemkonformes Speichern im gewünschten Album
      final asset = await PhotoManager.editor.saveVideo(
        videoFile,
        title: filename,
        relativePath: 'DCIM/$_selectedAlbumName', // <-- Wichtig!
      );

      if (asset == null) {
        debugPrint(
          '❌ Fehler: asset == null – Video konnte nicht gespeichert werden',
        );
        return;
      }

      // 2️⃣ Galerie / Explorer aktualisieren
      await Future.delayed(const Duration(seconds: 1));
      await loadAlbums();

      try {
        final found = _albums.firstWhere((a) => a.name == _selectedAlbumName);
        _selectedAlbum = found;
      } catch (_) {
        debugPrint('⚠️ Album "$_selectedAlbumName" noch nicht gefunden.');
      }

      await getNextFileCounter();
      debugPrint(
        '✅ Video gespeichert unter DCIM/$_selectedAlbumName/$filename',
      );
    } catch (e) {
      debugPrint('❌ Fehler beim Speichern des Videos: $e');
    }
  }

  // --- NÄCHSTEN FREIEN ZÄHLER FÜR TAGS ERMITTELN ---
  Future<int> getNextAvailableCounterForTags(List<String> parts) async {
    if (_selectedAlbum == null) {
      return _currentFileCounter;
    }

    try {
      final assets = await _selectedAlbum!.getAssetListPaged(
        page: 0,
        size: 1000,
      );

      final separator = parts.join('-').contains('_') ? '_' : '-';
      final baseName = parts.join(separator);
      int highest = 0;

      for (final asset in assets) {
        final title = asset.title?.toLowerCase() ?? '';
        if (title.startsWith(baseName.toLowerCase())) {
          final match = RegExp(r'(\d{3})(?=\.\w+$)').firstMatch(title);
          if (match != null) {
            final num = int.tryParse(match.group(1) ?? '') ?? 0;
            if (num > highest) highest = num;
          }
        }
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
      if (_selectedAlbum != null) {
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

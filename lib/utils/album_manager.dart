import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Basisordner innerhalb von DCIM, unter dem alle App-Alben liegen.
const String _baseFolderName = 'Prename-App';
const String _defaultAlbumName = _baseFolderName;
const String _managedAlbumsPrefsKey = 'managed_album_names';

class AlbumManager extends ChangeNotifier {

  static const MethodChannel _mediaScanChannel = MethodChannel(
    'com.example.atp_prename_app/media_scan',
  );

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

  int? _cachedSdkInt;

  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    final candidates = <String?>[
      Platform.version,
      Platform.operatingSystemVersion,
    ];
    for (final source in candidates) {
      if (source == null || source.isEmpty) continue;
      final matchApi = RegExp(r'API(?:\s*level)?\s*(\d+)').firstMatch(source);
      if (matchApi != null) {
        final value = int.tryParse(matchApi.group(1) ?? '');
        if (value != null) {
          _cachedSdkInt = value;
          return value;
        }
      }
      final matchSdk = RegExp(r'SDK\s*(\d+)').firstMatch(source);
      if (matchSdk != null) {
        final value = int.tryParse(matchSdk.group(1) ?? '');
        if (value != null) {
          _cachedSdkInt = value;
          return value;
        }
      }
    }

    try {
      final result = await _mediaScanChannel.invokeMethod<int>('getSdkInt');
      if (result != null) {
        _cachedSdkInt = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ SDK-Ermittlung fehlgeschlagen: $e');
    }

    return 0;
  }

  Future<bool> _rememberAlbum(String name) async {
    if (name.isEmpty || name == _defaultAlbumName) return false;
    if (_managedAlbumNames.contains(name)) return false;
    _managedAlbumNames.add(name);
    await _persistManagedAlbums();
    return true;
  }

  Future<String?> _ensureLegacyAlbumDirectory() async {
    if (!Platform.isAndroid) return null;
    final sdk = await _androidSdkInt();
    if (sdk >= 29 || sdk == 0) return null;

    String? basePath;
    try {
      basePath = await _mediaScanChannel.invokeMethod<String>('getLegacyDcim');
    } catch (e) {
      debugPrint('⚠️ Legacy-DCIM Pfad konnte nicht ermittelt werden: $e');
    }
    if (basePath == null || basePath.isEmpty) {
      final dcimDirs = await getExternalStorageDirectories(
        type: StorageDirectory.dcim,
      );
      if (dcimDirs == null || dcimDirs.isEmpty) return null;
      basePath = dcimDirs.first.path;
    }

    final baseDir = Directory(p.join(basePath, _baseFolderName));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    Directory targetDir = baseDir;
    if (_selectedAlbumName.isNotEmpty &&
        _selectedAlbumName != _defaultAlbumName) {
      targetDir = Directory(p.join(baseDir.path, _selectedAlbumName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
    }

    return targetDir.path;
  }

  // --- ALBEN LADEN ---
  Future<void> loadAlbums() async {
    await _ensureManagedAlbumsLoaded();

    PermissionState status;
    try {
      status = await PhotoManager.requestPermissionExtend();
    } catch (_) {
      status = PermissionState.denied;
    }
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
      final sdk = await _androidSdkInt();
      final isLegacy = Platform.isAndroid && sdk > 0 && sdk < 29;

      String? savedPath;

      if (isLegacy) {
        final targetDir = await _ensureLegacyAlbumDirectory();
        if (targetDir == null) {
          debugPrint('❌ Legacy-Zielordner konnte nicht erstellt werden.');
          return;
        }
        final destPath = p.join(targetDir, filename);
        await imageFile.copy(destPath);
        await imageFile.delete();
        try {
          await _mediaScanChannel.invokeMethod('scanFile', {'path': destPath});
        } catch (e) {
          debugPrint('⚠️ MediaScan fehlgeschlagen: $e');
        }
        savedPath = destPath;
      } else {
        final bytes = await imageFile.readAsBytes();
        final asset = await PhotoManager.editor.saveImage(
          bytes,
          filename: filename,
          title: filename,
          relativePath: relativePath,
        );
        savedPath = await asset.relativePath ?? relativePath;
      }

      debugPrint(
        '📁 Bild gespeichert (relativePath=${savedPath ?? "?"})',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      await loadAlbums();

      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        debugPrint('⚠️ Album "${_selectedAlbumName}" nicht gefunden.');
      }

      final added = await _rememberAlbum(_selectedAlbumName);
      if (added) {
        await loadAlbums();
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
      final sdk = await _androidSdkInt();
      final isLegacy = Platform.isAndroid && sdk > 0 && sdk < 29;

      String? savedPath;

      if (isLegacy) {
        final targetDir = await _ensureLegacyAlbumDirectory();
        if (targetDir == null) {
          debugPrint('❌ Legacy-Zielordner konnte nicht erstellt werden.');
          return;
        }
        final destPath = p.join(targetDir, filename);
        await videoFile.copy(destPath);
        await videoFile.delete();
        try {
          await _mediaScanChannel.invokeMethod('scanFile', {'path': destPath});
        } catch (e) {
          debugPrint('⚠️ MediaScan fehlgeschlagen: $e');
        }
        savedPath = destPath;
      } else {
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

        savedPath = await asset.relativePath ?? relativePath;
      }

      debugPrint(
        '📁 Video gespeichert (relativePath=${savedPath ?? "?"})',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      await loadAlbums();

      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        debugPrint('⚠️ Album "$_selectedAlbumName" noch nicht gefunden.');
      }

      final added = await _rememberAlbum(_selectedAlbumName);
      if (added) {
        await loadAlbums();
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
    required bool dateTagEnabled,
    String? dateTag,
    bool reserve = true,
  }) async {
    // Parameter erhalten aus Abwärtskompatibilität; der Zähler ist global.
    final _ = parts;
    final __ = separator;
    final ___ = dateTagEnabled;
    final ____ = dateTag;
    final _____ = reserve;

    int highest = 0;

    Future<void> inspectAlbum(AssetPathEntity album) async {
      final assets = await album.getAssetListPaged(page: 0, size: 1000);
      for (final asset in assets) {
        final title = asset.title ?? '';
        final match = RegExp(r'(\d{3})(?=\.\w+$)').firstMatch(title);
        if (match != null) {
          final value = int.tryParse(match.group(1) ?? '') ?? 0;
          if (value > highest) highest = value;
        }
      }
    }

    if (_selectedAlbumName == _defaultAlbumName) {
      for (final album in _albums) {
        await inspectAlbum(album);
      }
    } else if (_selectedAlbum != null) {
      await inspectAlbum(_selectedAlbum!);
    }

    return highest + 1;
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

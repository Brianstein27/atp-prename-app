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
  static const MethodChannel _iosMediaSaverChannel = MethodChannel(
    'com.example.atp_prename_app/ios_media_saver',
  );

  bool get _isDarwin => Platform.isIOS || Platform.isMacOS;

  // --- STATE ---
  AssetPathEntity? _selectedAlbum;
  String _selectedAlbumName = _defaultAlbumName;
  List<AssetPathEntity> _albums = [];
  int _currentFileCounter = 1;
  bool _hasPermission = false;
  final List<String> _managedAlbumNames = [];
  bool _managedAlbumsLoaded = false;
  final Map<String, String> _iosFilenameCache = {};

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
    final segments = <String>[];
    if (Platform.isAndroid) {
      segments.addAll(['DCIM', _baseFolderName]);
    } else {
      segments.add(_baseFolderName);
    }
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

  Future<AssetPathEntity?> _ensureDarwinAlbum(String name) async {
    if (!_isDarwin || name.isEmpty) return null;

    AssetPathEntity? findMatch(Iterable<AssetPathEntity> list) {
      for (final entry in list) {
        if (entry.name == name && entry.albumType == 1) {
          return entry;
        }
      }
      return null;
    }

    final existing = findMatch(_albums);
    if (existing != null) return existing;

    List<AssetPathEntity> allAlbums = [];
    try {
      allAlbums = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.common,
      );
    } catch (e) {
      debugPrint('⚠️ Albenliste konnte nicht geladen werden: $e');
    }

    final fromFetch = findMatch(allAlbums);
    if (fromFetch != null) return fromFetch;

    AssetPathEntity? created;
    try {
      created = await PhotoManager.editor.darwin.createAlbum(
        name,
        parent: null,
      );
    } catch (e) {
      debugPrint('⚠️ Album "$name" konnte nicht erstellt werden: $e');
    }
    if (created != null) return created;

    if (allAlbums.isEmpty) {
      try {
        allAlbums = await PhotoManager.getAssetPathList(
          onlyAll: false,
          type: RequestType.common,
        );
      } catch (_) {}
    }

    return findMatch(allAlbums);
  }

  Future<void> _addAssetToDarwinAlbum(
    AssetEntity asset, {
    String? targetAlbumName,
  }) async {
    if (!_isDarwin) return;
    final targetName = targetAlbumName ?? _selectedAlbumName;
    if (targetName.isEmpty) return;
    final album = await _ensureDarwinAlbum(targetName);
    if (album == null || album.isAll) return;
    try {
      await PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: album,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Asset konnte nicht dem Album "$targetName" hinzugefügt werden: $e',
      );
    }
  }

  Future<void> addAssetToDarwinAlbumByName({
    required String albumName,
    required String assetId,
  }) async {
    if (!_isDarwin) return;
    if (albumName.isEmpty) return;
    AssetEntity? asset = await _fetchAssetWithRetries(assetId);
    if (asset == null) {
      debugPrint(
        '⚠️ Neues Asset "$assetId" konnte nicht geladen werden. Album "$albumName" wird übersprungen.',
      );
      return;
    }
    await _addAssetToDarwinAlbum(asset, targetAlbumName: albumName);
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

  Future<AssetEntity?> _fetchAssetWithRetries(String assetId) async {
    AssetEntity? entity;
    for (var attempt = 0; attempt < 8; attempt++) {
      entity = await AssetEntity.fromId(assetId);
      if (entity != null) break;
      await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
    return entity;
  }

  Future<AssetEntity?> _saveDarwinAsset({
    required String method,
    required File file,
    required String filename,
  }) async {
    if (!Platform.isIOS) return null;
    try {
      final localId = await _iosMediaSaverChannel.invokeMethod<String>(
        method,
        {
          'path': file.path,
          'filename': filename,
        },
      );
      if (localId == null || localId.isEmpty) return null;

      AssetEntity? entity = await _fetchAssetWithRetries(localId);
      if (entity == null) {
        debugPrint('⚠️ Asset "$filename" gespeichert, aber nicht auffindbar.');
      }
      return entity;
    } on MissingPluginException {
      // iOS channel nicht verfügbar (z. B. macOS Build) → Fallback.
      return null;
    } catch (e) {
      debugPrint('⚠️ Darwin-Speichern fehlgeschlagen ($method): $e');
      return null;
    }
  }

  Future<String> resolveDisplayName(AssetEntity asset) async {
    final fallback = asset.title ?? asset.id;
    if (!_isDarwin) return fallback;
    final cached = _iosFilenameCache[asset.id];
    if (cached != null) return cached;
    try {
      final original = await _iosMediaSaverChannel.invokeMethod<String>(
        'getOriginalFilename',
        {'assetId': asset.id},
      );
      if (original != null && original.isNotEmpty) {
        _iosFilenameCache[asset.id] = original;
        return original;
      }
    } catch (e) {
      debugPrint('⚠️ Original filename lookup fehlgeschlagen: $e');
    }
    _iosFilenameCache[asset.id] = fallback;
    return fallback;
  }

  void cacheDisplayName(String assetId, String name) {
    if (!_isDarwin) return;
    _iosFilenameCache[assetId] = name;
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

    List<AssetPathEntity> allAlbums = [];
    try {
      allAlbums = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.common, // images + videos
      );
    } catch (e) {
      debugPrint('⚠️ Albenliste konnte nicht geladen werden: $e');
    }

    final expectedNames = <String>{
      _defaultAlbumName,
      ..._managedAlbumNames,
      if (_selectedAlbumName.isNotEmpty) _selectedAlbumName,
    }..removeWhere((name) => name.isEmpty);

    if (_isDarwin) {
      for (final name in expectedNames) {
        await _ensureDarwinAlbum(name);
      }
      try {
        allAlbums = await PhotoManager.getAssetPathList(
          onlyAll: false,
          type: RequestType.common,
        );
      } catch (e) {
        debugPrint('⚠️ Albenliste (Refresh) konnte nicht geladen werden: $e');
      }
    }

    final filtered = <AssetPathEntity>[
      for (final album in allAlbums)
        if (expectedNames.contains(album.name)) album,
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

    if (_isDarwin) {
      await _ensureDarwinAlbum(cleanedName);
    }

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

      late String savedPath;

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
      } else if (Platform.isAndroid) {
        final bytes = await imageFile.readAsBytes();
        final asset = await PhotoManager.editor.saveImage(
          bytes,
          filename: filename,
          title: filename,
          relativePath: relativePath,
        );
        savedPath = asset.relativePath ?? relativePath;
      } else {
    final wasDefaultAlbum =
        _selectedAlbumName.isEmpty || _selectedAlbumName == _defaultAlbumName;

    AssetEntity? asset = await _saveDarwinAsset(
      method: 'saveImage',
      file: imageFile,
      filename: filename,
    );

        if (asset == null) {
          try {
            asset = await PhotoManager.editor.saveImageWithPath(
              imageFile.path,
              title: filename,
            );
          } catch (e) {
            debugPrint('⚠️ iOS-Fallback (Foto) fehlgeschlagen: $e');
          }
        }

        if (asset == null) {
          debugPrint('❌ Bild konnte auf iOS nicht gespeichert werden.');
          return;
        }

        if (!wasDefaultAlbum) {
          await _addAssetToDarwinAlbum(asset);
        }
        cacheDisplayName(asset.id, filename);
        savedPath = asset.relativePath ?? relativePath;

        try {
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (_) {}
      }

      debugPrint('📁 Bild gespeichert (relativePath=$savedPath)');

      await Future.delayed(const Duration(milliseconds: 500));
      await loadAlbums();

      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        debugPrint('⚠️ Album "$_selectedAlbumName" nicht gefunden.');
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

      late String savedPath;

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
      } else if (Platform.isAndroid) {
        final asset = await PhotoManager.editor.saveVideo(
          videoFile,
          title: filename,
          relativePath: relativePath,
        );
        savedPath = asset.relativePath ?? relativePath;
      } else {
    final wasDefaultAlbum =
        _selectedAlbumName.isEmpty || _selectedAlbumName == _defaultAlbumName;

    AssetEntity? asset = await _saveDarwinAsset(
      method: 'saveVideo',
      file: videoFile,
      filename: filename,
    );

        if (asset == null) {
          try {
            asset = await PhotoManager.editor.saveVideo(
              videoFile,
              title: filename,
            );
          } catch (e) {
            debugPrint('⚠️ iOS-Fallback (Video) fehlgeschlagen: $e');
          }
        }

        if (asset == null) {
          debugPrint('❌ Video konnte auf iOS nicht gespeichert werden.');
          return;
        }

        if (!wasDefaultAlbum) {
          await _addAssetToDarwinAlbum(asset);
        }
        cacheDisplayName(asset.id, filename);
        savedPath = asset.relativePath ?? relativePath;

        try {
          if (await videoFile.exists()) {
            await videoFile.delete();
          }
        } catch (_) {}
      }

      debugPrint('📁 Video gespeichert (relativePath=$savedPath)');

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
    assert(() {
      // Zugriff hält alte Signatur kompatibel, ohne Release-Code zu beeinflussen.
      // ignore: unused_local_variable
      final debugTuple = (parts, separator, dateTagEnabled, dateTag, reserve);
      return true;
    }());

    int highest = 0;

    Future<void> inspectAlbum(AssetPathEntity album) async {
      final assets = await album.getAssetListPaged(page: 0, size: 1000);
      for (final asset in assets) {
        var title = asset.title ?? '';
        if (_isDarwin) {
          title = await resolveDisplayName(asset);
        }
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

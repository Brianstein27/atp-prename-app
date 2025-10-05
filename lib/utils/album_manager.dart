import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

/// Standard-Albumname, wenn noch kein Album gewählt ist.
const String _defaultAlbumName = 'Pictures';

class AlbumManager extends ChangeNotifier {
  // --- Zustand ---
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

  // --- Platform Channel für MediaScan (Android) ---
  static const _channel = MethodChannel(
    'com.example.atp_prename_app/media_scan',
  );

  // --- Alben laden ---
  Future<void> loadAlbums() async {
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
      type: RequestType.image,
    );

    // Entferne "Recent", "Recents" oder den virtuellen ID-Eintrag "all"
    _albums = allAlbums.where((album) {
      final lower = album.name.toLowerCase();
      final isRecent =
          (lower == 'recent' || lower == 'recents' || album.id == 'all');
      final isInDCIM = album.name.isNotEmpty && !isRecent;
      return isInDCIM;
    }).toList();

    if (_selectedAlbum == null && _selectedAlbumName != _defaultAlbumName) {
      try {
        _selectedAlbum = _albums.firstWhere(
          (a) => a.name == _selectedAlbumName,
        );
      } catch (_) {
        // Album noch nicht vorhanden
      }
    }

    notifyListeners();
  }

  // --- Album auswählen ---
  void selectAlbum(AssetPathEntity album) {
    _selectedAlbum = album;
    _selectedAlbumName = album.name;
    _currentFileCounter = 1;
    getNextFileCounter();
    notifyListeners();
  }

  // --- Album erstellen (Album wird bei erstem Bild automatisch angelegt) ---
  Future<void> createAlbum(String name) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return;

    _selectedAlbumName = cleanedName;
    _selectedAlbum = null;

    await loadAlbums();

    final exists = _albums.any((a) => a.name == cleanedName);
    if (exists) {
      _selectedAlbum = _albums.firstWhere((a) => a.name == cleanedName);
    } else {
      debugPrint('📁 Album wird automatisch bei erster Speicherung erstellt.');
    }

    _currentFileCounter = 1;
    notifyListeners();
  }

  // --- Bild speichern (einmalig, mit richtigem Namen, kein Duplikat) ---
  Future<void> saveImage(File imageFile, String filename) async {
    try {
      if (!_hasPermission) {
        await loadAlbums();
        if (!_hasPermission) {
          debugPrint('❌ Keine Berechtigung zum Speichern.');
          return;
        }
      }

      // 📂 Zielpfad im DCIM/<AlbumName>
      final Directory dcimDir = Directory(
        '/storage/emulated/0/DCIM/$_selectedAlbumName',
      );

      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
        debugPrint('📁 Album-Ordner erstellt: ${dcimDir.path}');
      }

      final targetPath = '${dcimDir.path}/$filename';
      final targetFile = File(targetPath);

      // ⚙️ Datei kopieren (einmalig, richtiger Name)
      if (!await targetFile.exists()) {
        await imageFile.copy(targetFile.path);
        debugPrint('✅ Bild gespeichert: $targetPath');
      } else {
        debugPrint('⚠️ Datei existiert bereits: $targetPath');
      }

      // 🛰️ Jetzt den MediaScanner informieren (das ist der entscheidende Teil!)
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('scanFile', {'path': targetFile.path});
          debugPrint('📡 MediaScanner wurde aufgerufen für: $targetPath');
        } catch (e) {
          debugPrint('⚠️ Fehler beim MediaScan: $e');
        }
      }

      // 🔁 Jetzt 1–2 Sekunden warten, bis Android das neue Asset registriert hat
      await Future.delayed(const Duration(seconds: 1));

      // 📋 Alben neu laden, damit das neue Album erscheint
      await loadAlbums();

      // Falls das Album jetzt gefunden wird → als aktiv setzen
      try {
        final found = _albums.firstWhere((a) => a.name == _selectedAlbumName);
        _selectedAlbum = found;
        debugPrint('✅ Album "$_selectedAlbumName" jetzt indiziert.');
      } catch (_) {
        debugPrint('⚠️ Album "$_selectedAlbumName" noch nicht gefunden.');
      }

      await getNextFileCounter();
    } catch (e) {
      debugPrint('❌ Fehler beim Speichern der Datei: $e');
    }
  }

  // --- Nächster Dateizähler ---
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

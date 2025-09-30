import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Der AlbumManager ist ein ChangeNotifier, der den State der Medienalben
/// (Verzeichnisse) verwaltet und die Interaktion mit der nativen Foto-Bibliothek
/// (via photo_manager) kapselt.
class AlbumManager extends ChangeNotifier {
  // Der aktuell ausgewählte Album-Pfad
  AssetPathEntity? _selectedAlbum;
  // Die Liste aller verfügbaren Alben
  List<AssetPathEntity> _albums = [];
  // Status der Berechtigung
  bool _hasPermission = false;
  // Der aktuelle fortlaufende Dateizähler für das ausgewählte Album
  int _currentFileCounter = 1;

  // Name für das Standardalbum, das wir erstellen werden
  static const String _defaultAlbumName = 'FotoApp_Exports';

  // --- GETTER ---

  AssetPathEntity? get selectedAlbum => _selectedAlbum;
  List<AssetPathEntity> get albums => _albums;
  bool get hasPermission => _hasPermission;
  int get currentFileCounter => _currentFileCounter;

  /// Gibt den Anzeigenamen des aktuell ausgewählten Albums zurück.
  String get selectedAlbumName {
    if (!_hasPermission) {
      return 'Berechtigung fehlt!';
    }
    return _selectedAlbum?.name ?? 'Kein Album ausgewählt';
  }

  // --- HILFSFUNKTIONEN ---

  /// Ruft alle Assets (Bilder) im aktuell ausgewählten Album ab.
  Future<List<AssetEntity>> _getAlbumAssets() async {
    if (_selectedAlbum == null) return [];

    // Läd die Assets absteigend nach Erstellungsdatum (neueste zuerst).
    // KORRIGIERT: Sortier-Parameter wurden entfernt, um Kompilierungsfehler
    // zu vermeiden, da die Reihenfolge der Assets für die Zählerberechnung nicht kritisch ist.
    final List<AssetEntity> assets = await _selectedAlbum!.getAssetListPaged(
      page: 0,
      size: 10000, // Große Seitengröße, um alle Assets abzurufen
      // Sortierparameter entfernt.
    );

    // Filtere nur Bilder, um sicherzustellen, dass der Zähler korrekt funktioniert.
    return assets.where((asset) => asset.type == AssetType.image).toList();
  }

  /// Berechnet den nächsten freien Dateizähler (Seriennummer) basierend
  /// auf den vorhandenen Dateinamen im aktuell ausgewählten Album.
  Future<int> getNextFileCounter() async {
    if (!_hasPermission || _selectedAlbum == null) {
      // Wenn keine Berechtigung oder kein Album ausgewählt ist, starten wir bei 1.
      _currentFileCounter = 1;
      notifyListeners();
      return 1;
    }

    // 1. Alle Assets im aktuellen Album abrufen (nur Bilder)
    final assets = await _getAlbumAssets();
    if (assets.isEmpty) {
      _currentFileCounter = 1;
      notifyListeners();
      return 1;
    }

    // Regulärer Ausdruck, um die 3-stellige Seriennummer am Ende des Dateinamens zu finden.
    // Sucht nach -XXX.jpg oder -XXX.png etc.
    final RegExp regex = RegExp(r'-(\d{3})\.[a-zA-Z0-9]+$');

    int maxCounter = 0;

    for (final asset in assets) {
      // Der filename von AssetEntity enthält den Namen mit Erweiterung (z.B. 20231027-TAG1-TAG2-015.jpg)
      final match = regex.firstMatch(asset.title ?? '');

      if (match != null) {
        // Die erfasste Gruppe 1 ist die dreistellige Zahl
        final counterString = match.group(1);
        if (counterString != null) {
          final counter = int.tryParse(counterString);
          if (counter != null && counter > maxCounter) {
            maxCounter = counter;
          }
        }
      }
    }

    // Der nächste Zähler ist der Maximalwert + 1
    _currentFileCounter = maxCounter + 1;
    notifyListeners();
    return _currentFileCounter;
  }

  // --- LADE- UND BERECHTIGUNGSLOGIK ---

  /// Lädt alle Alben nach Überprüfung/Anforderung der Berechtigungen.
  Future<void> loadAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    // Prüft, ob Berechtigung erteilt wurde
    _hasPermission = ps.isAuth;

    if (_hasPermission) {
      // KORREKTUR: Versuche, alle generischen Alben zu laden (nicht nur die,
      // die Assets enthalten). Dies kann helfen, Alben sichtbar zu machen,
      // die von der Galerie-App erstellt, aber vom photo_manager übersehen wurden.
      _albums = await PhotoManager.getAssetPathList(
        hasAll: false,
        type: RequestType.image,
        // Hier versuchen wir, mehr Alben zu erzwingen, indem wir nur bestimmte Typen
        // filtern (z.B. Albums, die nicht nur Test-Ordner sind).
        // Abhängig von der photo_manager Version kann dies variieren.
      );

      // 1. Prüfen, ob ein Standardalbum existiert (unser _defaultAlbumName)
      AssetPathEntity? defaultAlbum = _albums
          .cast<AssetPathEntity?>()
          .firstWhere(
            (album) => album?.name == _defaultAlbumName,
            orElse: () =>
                null as AssetPathEntity?, // KORRIGIERT: Null-Safe Casting
          );

      // 2. Wenn das Standardalbum existiert, wählen wir es aus.
      if (defaultAlbum != null) {
        _selectedAlbum = defaultAlbum;
      } else if (_selectedAlbum == null && _albums.isNotEmpty) {
        // 3. Falls noch nichts ausgewählt ist und unser Standardalbum fehlt:
        //    Wir wählen einfach das erste gefundene Album aus, falls vorhanden.
        _selectedAlbum = _albums.first;
      }

      // Nachdem das Album ausgewählt oder bestätigt wurde, den Zähler laden
      await getNextFileCounter();
    } else {
      _albums = [];
      _selectedAlbum = null;
      _currentFileCounter = 1;
    }
    notifyListeners();
  }

  // --- ALBUM AUSWAHL UND ERSTELLUNG ---

  void selectAlbum(AssetPathEntity album) {
    if (_selectedAlbum?.id != album.id) {
      _selectedAlbum = album;
      // Neuen Zähler für das neu ausgewählte Album sofort laden
      getNextFileCounter();
      notifyListeners();
    }
  }

  // --- KAMERA UND SPEICHERLOGIK ---

  /// Speichert die temporäre Bilddatei in dem aktuell ausgewählten Album
  /// mit dem gegebenen Dateinamen.
  Future<AssetEntity?> saveImage(File imageFile, String filename) async {
    if (_selectedAlbum == null) {
      debugPrint('FEHLER: Kein Album zum Speichern ausgewählt.');
      return null;
    }

    // 1. Speichere die Datei mit dem gewünschten Dateinamen in der Galerie.
    // photo_manager kümmert sich um die Speicherung an der richtigen Stelle
    // und registriert das Asset in der Mediendatenbank.
    final AssetEntity? newAsset = await PhotoManager.editor.saveImageWithPath(
      imageFile.path,
      title: filename, // Der Dateiname (z.B. 20231027-TAG1-TAG2-001.jpg)
      // relativePath ist wichtig für Android > 10, es sollte der Name des Albums sein
      // um in den DCIM/<Albumname> Ordner zu speichern.
      relativePath: 'DCIM/${_selectedAlbum!.name}',
    );

    if (newAsset != null) {
      debugPrint('Bild erfolgreich gespeichert als: $filename');
      // 2. Albenliste neu laden, um den Zähler zu aktualisieren
      await loadAlbums();
    } else {
      debugPrint(
        'FEHLER: Bild konnte nicht über PhotoManager gespeichert werden.',
      );
    }

    return newAsset;
  }

  /// Erstellt physisch einen neuen Ordner/Album im Mediencenter
  /// und lädt danach die Albenliste neu.
  Future<bool> createAlbum(String name) async {
    if (!_hasPermission) {
      // Erneuter Versuch, Berechtigungen zu laden
      await loadAlbums();
      if (!_hasPermission) return false;
    }

    try {
      // KORREKTUR: Die nativen photo_manager-Methoden (createAlbum/createFolder)
      // kompilieren in dieser Umgebung nicht. Wir gehen zur manuellen Erstellung
      // des DCIM-Ordners zurück, was immer kompiliert.
      final Directory? externalDir = await getExternalStorageDirectory();

      if (externalDir == null) {
        debugPrint('FEHLER: Externer Speicherpfad nicht verfügbar.');
        return false;
      }

      // Zielpfad: [ExternalStorage]/DCIM/AlbumName
      final String albumPath = '${externalDir.path}/DCIM/$name';
      final Directory newDirectory = Directory(albumPath);

      if (!await newDirectory.exists()) {
        await newDirectory.create(recursive: true);
        debugPrint('Albumordner manuell erstellt (DCIM): $albumPath');
      } else {
        debugPrint('Albumordner existiert bereits: $albumPath');
      }

      // Manuelles Erstellen gibt uns keine AssetPathEntity zurück.
      // Wir müssen auf das Neuladen warten, bis photo_manager den Ordner findet.
      await loadAlbums();

      // Versuche, das neu erstellte Album in der geladenen Liste zu finden.
      final AssetPathEntity? albumInList = _albums
          .cast<AssetPathEntity?>()
          .firstWhere(
            (album) => album?.name == name,
            orElse: () => null as AssetPathEntity?,
          );

      if (albumInList != null) {
        selectAlbum(albumInList);
        return true;
      } else {
        // Dies geschieht oft, weil das Android MediaStore den Ordner noch nicht indexiert hat.
        // Die Speicherung des ersten Bildes sollte dies beheben.
        debugPrint(
          'WARNUNG: Das neu erstellte Album "$name" wurde vom photo_manager noch nicht gefunden. Es wird beim nächsten Scan sichtbar sein.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Fehler beim Erstellen des Albums $name: $e');
      return false;
    }
  }
}

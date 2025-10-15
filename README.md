# atp_prename_app

Foto- und Video-App zum komfortablen Aufnehmen, Benennen, Organisieren und Teilen von Medien auf Android (Flutter).

## Architekturüberblick

- **App-Start**: `lib/main.dart` initialisiert Flutter-Bindings, registriert einen globalen `ChangeNotifierProvider` und rendert `FotoApp`, deren Home `MainScreen` ist.
- **Navigation**: `lib/pages/main_screen.dart` stellt das Gerüst mit AppBar und Drawer bereit, um zwischen Home (Aufnahme), Explorer (Galerie) und Einstellungen zu wechseln.
- **State Management**: `lib/utils/album_manager.dart` kapselt Berechtigungen, Albumauswahl, Medien-Speicherung und das Hochzählen des Dateinamenzählers. Der Manager nutzt `photo_manager`, legt alle Medien unter `DCIM/Prename-App/<Album>` ab (oder im Basisordner, wenn kein Album gewählt ist) und aktualisiert nach jedem Speichern den aktuellen Zähler.
- **Aufnahme & Benennung**:  
  - `lib/pages/home_page.dart` erstellt Dateinamen aus Datum, frei definierbaren Tags (A–F) und einem laufenden Zähler (`001`–`999`), gesteuert über das in den Einstellungen gewählte Trennzeichen. Jede Tag-Zeile öffnet beim Antippen einen Auswahldialog mit Suchfeld zum Anlegen neuer Tags (max. 20 Zeichen) sowie einer Liste zuvor gespeicherter Werte (`SharedPreferences`).  
  - `lib/utils/camera_button.dart` und `lib/pages/camera_capture_page.dart` koordinieren Foto- und Videoaufnahme (Video mit Vorschau-Dialog und Optionen Speichern/Verwerfen/Neu aufnehmen).  
  - Fertige Dateien werden über `AlbumManager.saveImage` bzw. `saveVideo` persistiert.
- **Galerie & Verwaltung**: `lib/pages/explorer_page.dart` lädt Medien des ausgewählten Albums, bietet Sortierung (Name/Datum, auf/absteigend), Textsuche, Mehrfachauswahl, Teilen (`share_plus`) und Löschen. Einzelne Dateien lassen sich umbenennen oder in `fullscreen_image_page.dart` bzw. `video_player_page.dart` ansehen.
- **Einstellungen**: `lib/pages/settings_page.dart` speichert das gewünschte Dateinamenseparator (`-`/`_`) in `SharedPreferences`. `HomePage` liest den Wert beim Bootstrapping ein.
- **Tests**: `test/widget_test.dart` enthält noch den Flutter-Standardtest (`MyApp` Counter) und passt nicht mehr zum aktuellen Einstiegspunkt. Er kann entfernt oder auf `FotoApp`/`MainScreen` angepasst werden, sobald Widget-Tests benötigt werden.

## Voraussetzungen

- Flutter SDK (>= 3.9.0)
- Android-Gerät oder -Emulator mit Kamera/Galerie-Berechtigungen (iOS aktuell ungetestet)

Alle verwendeten Plugins sind in `pubspec.yaml` hinterlegt (u. a. `photo_manager`, `camera`, `image_picker`, `share_plus`, `shared_preferences`, `chewie`).

## Entwicklung starten

```bash
flutter pub get
flutter run
```

Für Video-/Fotoaufnahme sollte ein physisches Gerät genutzt werden; Emulatoren unterstützen dies nur eingeschränkt.

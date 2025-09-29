import 'package:flutter/material.dart';

class CameraButton extends StatelessWidget {
  final String filename;
  final String selectedAlbumName;
  final VoidCallback onCameraPressed;

  const CameraButton({
    super.key,
    required this.filename,
    required this.selectedAlbumName,
    required this.onCameraPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.camera_alt),
      label: const Text('Kamera öffnen', style: TextStyle(fontSize: 18)),
      onPressed: () async {
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Foto aufnehmen?'),
            content: Text(
              'Hier wird dann die Kamera auftauchen \n\n'
              'Das Bild wird in dem Album "$selectedAlbumName" gespeichert und '
              'erhält den Dateinamen:\n\n$filename',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bestätigen'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          onCameraPressed();
        }
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60), // Volle Breite
        backgroundColor: Colors.lightGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}

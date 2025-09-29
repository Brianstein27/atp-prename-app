import 'package:flutter/material.dart';

class FilenamePreview extends StatelessWidget {
  final String filename;

  const FilenamePreview({super.key, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dateiname Vorschau (inkl. Seriennr. 001)',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            border: Border.all(color: Colors.blueGrey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            filename,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
              fontFamily:
                  'monospace', // Monospace für bessere Lesbarkeit von Dateinamen
            ),
          ),
        ),
      ],
    );
  }
}

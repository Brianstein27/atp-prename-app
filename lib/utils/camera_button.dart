import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraButton extends StatefulWidget {
  final String filename;
  final String selectedAlbumName;
  final VoidCallback onCameraPressed;
  final VoidCallback onVideoPressed;
  final ValueChanged<bool>? onModeChanged;

  const CameraButton({
    super.key,
    required this.filename,
    required this.selectedAlbumName,
    required this.onCameraPressed,
    required this.onVideoPressed,
    this.onModeChanged,
  });

  @override
  State<CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<CameraButton> {
  bool _isVideoMode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Video-Modus aktivieren'),
          value: _isVideoMode,
          onChanged: (value) {
            setState(() => _isVideoMode = value);
            widget.onModeChanged?.call(value);
          },
          activeColor: Colors.lightGreen,
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: Icon(_isVideoMode ? Icons.videocam : Icons.camera_alt),
          label: Text(
            _isVideoMode ? 'Video aufnehmen' : 'Foto aufnehmen',
            style: const TextStyle(fontSize: 18),
          ),
          onPressed: _isVideoMode
              ? widget.onVideoPressed
              : widget.onCameraPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            backgroundColor: Colors.lightGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

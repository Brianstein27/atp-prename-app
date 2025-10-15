import 'package:flutter/material.dart';

class CameraButton extends StatefulWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onVideoPressed;
  final ValueChanged<bool>? onModeChanged;

  const CameraButton({
    super.key,
    required this.onCameraPressed,
    required this.onVideoPressed,
    this.onModeChanged,
  });

  @override
  State<CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<CameraButton> {
  bool _isVideoMode = false;

  void _handlePhotoPressed() {
    setState(() => _isVideoMode = false);
    widget.onModeChanged?.call(false);
    widget.onCameraPressed();
  }

  void _handleVideoPressed() {
    setState(() => _isVideoMode = true);
    widget.onModeChanged?.call(true);
    widget.onVideoPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Foto aufnehmen'),
                onPressed: _handlePhotoPressed,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: _isVideoMode
                      ? Colors.lightGreen.shade100
                      : Colors.lightGreen,
                  foregroundColor: _isVideoMode
                      ? Colors.lightGreen.shade900
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Video aufnehmen'),
                onPressed: _handleVideoPressed,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: _isVideoMode
                      ? Colors.lightGreen
                      : Colors.lightGreen.shade100,
                  foregroundColor: _isVideoMode
                      ? Colors.white
                      : Colors.lightGreen.shade900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

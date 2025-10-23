import 'dart:io';

import 'package:flutter/material.dart';

import 'explorer_page.dart';
import '../services/camera_service.dart';
import 'package:camera/camera.dart';

class CameraCapturePage extends StatefulWidget {
  final bool initialVideoMode;
  final Future<String> Function(bool isVideo) requestFilename;
  final Future<void> Function(File file, String filename, bool isVideo)
      onMediaCaptured;

  const CameraCapturePage({
    super.key,
    required this.initialVideoMode,
    required this.requestFilename,
    required this.onMediaCaptured,
  });

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;
  bool _isBusy = false;
  late bool _isVideoMode;
  String _currentFilename = '';

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.initialVideoMode;
    _initializeControllerFuture = _setupCamera();
    _prepareFilename();
  }

  Future<void> _setupCamera() async {
    try {
      _controller = await CameraService.instance.getController();
      if (_controller != null && _controller!.value.isPreviewPaused) {
        try {
          await _controller!.resumePreview();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Kamera konnte nicht initialisiert werden: $e');
      rethrow;
    }
  }

  Future<void> _prepareFilename() async {
    final name = await widget.requestFilename(_isVideoMode);
    if (!mounted) return;
    setState(() => _currentFilename = name);
  }

  @override
  void dispose() {
    try {
      _controller?.pausePreview();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    if (_isRecording && _controller != null) {
      try {
        await _controller!.stopVideoRecording();
      } catch (_) {
        // ignore errors when stopping
      }
      _isRecording = false;
    }
    try {
      await _controller?.pausePreview();
    } catch (_) {}
    if (mounted) Navigator.pop(context, _isVideoMode);
  }

  Future<void> _openExplorer() async {
    if (_isRecording || _isBusy) return;
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.pausePreview();
      } catch (_) {}
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExplorerPage()),
    );

    try {
      await controller?.resumePreview();
    } catch (_) {}
    _isRecording = false;
    await _prepareFilename();
  }

  Future<void> _switchMode(bool video) async {
    if (_isBusy || (_isRecording && video == _isVideoMode)) return;
    setState(() {
      _isVideoMode = video;
      _isRecording = false;
    });
    await _prepareFilename();
  }

  Future<void> _captureMedia() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      await _initializeControllerFuture;
      final controller = _controller;
      if (controller == null) return;

      if (_isVideoMode) {
        if (_isRecording) {
          final videoFile = await controller.stopVideoRecording();
          final savedFile = File(videoFile.path);
          final filename = _currentFilename.isEmpty
              ? await widget.requestFilename(true)
              : _currentFilename;
          setState(() => _isRecording = false);
          await widget.onMediaCaptured(savedFile, filename, true);
          await _prepareFilename();
          try {
            await controller.resumePreview();
          } catch (_) {}
        } else {
          if (_currentFilename.isEmpty) await _prepareFilename();
          await controller.startVideoRecording();
          setState(() => _isRecording = true);
        }
      } else {
        if (_currentFilename.isEmpty) await _prepareFilename();
        final image = await controller.takePicture();
        final filename = _currentFilename.isEmpty
            ? await widget.requestFilename(false)
            : _currentFilename;
        await widget.onMediaCaptured(File(image.path), filename, false);
        await _prepareFilename();
      }
    } catch (e) {
      debugPrint('❌ Fehler bei Aufnahme: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBackNavigation();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }
            if (snapshot.connectionState == ConnectionState.done &&
                _controller != null) {
              return Stack(
                children: [
                  Center(child: CameraPreview(_controller!)),
                  _buildTopOverlay(context),
                  _buildBottomControls(),
                  if (_isRecording)
                    const Positioned(
                      top: 20,
                      right: 20,
                      child: Icon(Icons.fiber_manual_record, color: Colors.red),
                    ),
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            'Kamera konnte nicht gestartet werden.\n${error ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _initializeControllerFuture = _setupCamera();
              });
            },
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOverlay(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Zurück',
            onPressed: _handleBackNavigation,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentFilename.isEmpty ? '...' : _currentFilename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundIconButton(
              icon: Icons.photo_library_outlined,
              tooltip: 'Explorer öffnen',
              onPressed: _openExplorer,
            ),
            const SizedBox(width: 24),
            FloatingActionButton(
              heroTag: 'captureButton',
              backgroundColor: _isVideoMode
                  ? (_isRecording ? Colors.red : Colors.lightGreen)
                  : Colors.lightGreen,
              onPressed: _captureMedia,
              child: Icon(
                _isVideoMode
                    ? (_isRecording ? Icons.stop : Icons.videocam)
                    : Icons.camera_alt,
              ),
            ),
            const SizedBox(width: 24),
            _RoundIconButton(
              icon: _isVideoMode
                  ? Icons.photo_camera_outlined
                  : Icons.videocam_outlined,
              tooltip: _isVideoMode
                  ? 'Zum Fotomodus wechseln'
                  : 'Zum Videomodus wechseln',
              onPressed: () => _switchMode(!_isVideoMode),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'explorer_page.dart';

class CameraCapturePage extends StatefulWidget {
  final bool isVideoMode;
  final Future<String> Function() requestFilename;
  final Future<void> Function(File file, String filename) onMediaCaptured;

  const CameraCapturePage({
    super.key,
    required this.isVideoMode,
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
  String _currentFilename = '';

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _setupCamera();
    _prepareFilename();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: widget.isVideoMode,
    );

    await _controller!.initialize();
  }

  Future<void> _prepareFilename() async {
    final name = await widget.requestFilename();
    if (!mounted) return;
    setState(() => _currentFilename = name);
  }

  @override
  void dispose() {
    _controller?.dispose();
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
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openExplorer() async {
    if (_isRecording || _isBusy) return;
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
      _controller = null;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExplorerPage()),
    );

    setState(() {
      _initializeControllerFuture = _setupCamera();
    });
    await _prepareFilename();
  }

  Future<void> _captureMedia() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      await _initializeControllerFuture;
      if (_controller == null) return;

      if (widget.isVideoMode) {
        // 🎥 Videoaufnahme
        if (_isRecording) {
          final videoFile = await _controller!.stopVideoRecording();
          final savedFile = File(videoFile.path);
          final filename = _currentFilename.isEmpty
              ? await widget.requestFilename()
              : _currentFilename;
          setState(() {
            _isRecording = false;
          });

          await widget.onMediaCaptured(savedFile, filename);
          await _controller?.dispose();
          _controller = null;
          setState(() {
            _initializeControllerFuture = _setupCamera();
          });
          await _prepareFilename();
        } else {
          if (_currentFilename.isEmpty) {
            await _prepareFilename();
          }
          await _controller!.startVideoRecording();
          setState(() => _isRecording = true);
        }
      } else {
        // 📸 Fotoaufnahme
        final image = await _controller!.takePicture();
        final filename = _currentFilename.isEmpty
            ? await widget.requestFilename()
            : _currentFilename;
        await widget.onMediaCaptured(File(image.path), filename);
        await _prepareFilename();
      }
    } catch (e) {
      debugPrint('❌ Fehler bei Aufnahme: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  // Video-Vorschau wurde entfernt, um direkt nach Aufnahme bereit zu bleiben

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            return Stack(
              children: [
                Center(child: CameraPreview(_controller!)),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'Zurück',
                          onPressed: _handleBackNavigation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentFilename.isEmpty
                                ? '...'
                                : _currentFilename,
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
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                          child: IconButton(
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                            ),
                            tooltip: 'Explorer öffnen',
                            onPressed: _openExplorer,
                          ),
                        ),
                        const SizedBox(width: 24),
                        FloatingActionButton(
                          heroTag: 'captureButton',
                          backgroundColor: widget.isVideoMode
                              ? (_isRecording ? Colors.red : Colors.lightGreen)
                              : Colors.lightGreen,
                          onPressed: _captureMedia,
                          child: Icon(
                            widget.isVideoMode
                                ? (_isRecording ? Icons.stop : Icons.videocam)
                                : Icons.camera_alt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isRecording)
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: Icon(Icons.fiber_manual_record, color: Colors.red),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

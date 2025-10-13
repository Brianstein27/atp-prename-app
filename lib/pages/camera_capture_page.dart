import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CameraCapturePage extends StatefulWidget {
  final bool isVideoMode;
  final String filename;
  final Function(File) onMediaCaptured;

  const CameraCapturePage({
    super.key,
    required this.isVideoMode,
    required this.filename,
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
  File? _lastCapturedVideo;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _setupCamera();
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
          setState(() {
            _isRecording = false;
            _lastCapturedVideo = File(videoFile.path);
          });

          // 📺 Vorschau anzeigen
          await _showVideoPreview(_lastCapturedVideo!);
        } else {
          await _controller!.startVideoRecording();
          setState(() => _isRecording = true);
        }
      } else {
        // 📸 Fotoaufnahme
        final image = await _controller!.takePicture();
        widget.onMediaCaptured(File(image.path));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Fehler bei Aufnahme: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _showVideoPreview(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();
    controller.setLooping(true);
    controller.play();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Video überprüfen',
            style: TextStyle(color: Colors.white),
          ),
          content: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actions: [
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: () async {
                controller.dispose();
                if (await videoFile.exists()) {
                  await videoFile.delete();
                }
                Navigator.pop(context, 'discard');
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                controller.dispose();
                Navigator.pop(context, 'save');
              },
              child: const Text('Speichern'),
            ),
            IconButton(
              icon: Icon(Icons.loop, color: Colors.deepOrange),
              onPressed: () async {
                controller.dispose();
                if (await videoFile.exists()) {
                  await videoFile.delete();
                }
                Navigator.pop(context, 'retake');
              },
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted) return;

    if (result == 'save') {
      widget.onMediaCaptured(videoFile);
      Navigator.pop(context); // zurück zur Homepage
    } else if (result == 'retake') {
      // Kamera neustarten, ohne die Seite zu verlassen
      await _controller?.dispose();
      _controller = null;
      setState(() {
        _initializeControllerFuture = _setupCamera();
        _isRecording = false;
      });
    } else {
      Navigator.pop(context); // "discard" → einfach zurück zur Homepage
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.isVideoMode ? 'Video aufnehmen' : 'Foto aufnehmen'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            return Stack(
              children: [
                Center(child: CameraPreview(_controller!)),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
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
    );
  }
}

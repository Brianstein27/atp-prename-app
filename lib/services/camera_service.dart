import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraService._();

  static final CameraService instance = CameraService._();

  CameraController? _controller;
  Future<void>? _initializing;

  CameraController? get controller => _controller;

  Future<void> warmUp({bool background = false}) async {
    if (_initializing != null) {
      try {
        await _initializing;
      } catch (_) {
        if (!background) rethrow;
      }
      return;
    }

    _initializing = _initializeController();
    try {
      await _initializing;
    } catch (e, stack) {
      _initializing = null;
      _controller = null;
      if (background) {
        debugPrint('⚠️ Kamera-Vorinitialisierung fehlgeschlagen: $e');
        debugPrint('$stack');
      } else {
        rethrow;
      }
    }
  }

  Future<CameraController> getController() async {
    if (_controller != null && _controller!.value.isInitialized) {
      return _controller!;
    }

    if (_initializing != null) {
      try {
        await _initializing;
      } catch (_) {
        // Fehler wird unten erneut behandelt.
      }
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return _controller!;
    }

    await warmUp();

    final controller = _controller;
    if (controller == null) {
      throw CameraException(
        'uninitialized',
        'CameraController konnte nicht initialisiert werden',
      );
    }
    return controller;
  }

  Future<void> release() async {
    await _controller?.dispose();
    _controller = null;
    _initializing = null;
  }

  Future<void> _initializeController() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('notfound', 'Keine Kamera gefunden');
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    await controller.initialize();

    _controller = controller;
  }
}

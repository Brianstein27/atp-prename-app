import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import 'package:camera/camera.dart';
import '../l10n/localization_helper.dart';
import 'package:provider/provider.dart';
import '../utils/tab_navigation_model.dart';

class CameraCapturePage extends StatefulWidget {
  final bool initialVideoMode;
  final Future<String> Function(bool isVideo, {bool reserve}) requestFilename;
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

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;
  bool _isBusy = false;
  late bool _isVideoMode;
  String _currentFilename = '';
  FlashMode _flashMode = FlashMode.auto;
  static const List<FlashMode> _flashCycleOrder = [
    FlashMode.auto,
    FlashMode.off,
    FlashMode.always,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      await _applyFlashMode();
    } catch (e) {
      debugPrint('❌ Kamera konnte nicht initialisiert werden: $e');
      rethrow;
    }
  }

  Future<void> _prepareFilename() async {
    final name = await widget.requestFilename(
      _isVideoMode,
      reserve: false,
    );
    if (!mounted) return;
    setState(() => _currentFilename = name);
  }

  Future<void> _applyFlashMode() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setFlashMode(_flashMode);
    } catch (e) {
      debugPrint('❌ Blitzmodus konnte nicht gesetzt werden: $e');
    }
  }

  Future<void> _cycleFlashMode() async {
    final controller = _controller;
    if (controller == null) return;
    final currentIndex =
        _flashCycleOrder.indexWhere((mode) => mode == _flashMode);
    final nextMode =
        _flashCycleOrder[(currentIndex + 1) % _flashCycleOrder.length];
    try {
      await controller.setFlashMode(nextMode);
      if (!mounted) return;
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('❌ Blitzmodus konnte nicht gesetzt werden: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_handleAppLifecyclePaused());
        break;
      case AppLifecycleState.resumed:
        unawaited(_handleAppLifecycleResumed());
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _handleAppLifecyclePaused() async {
    final controller = _controller;
    if (_isRecording && controller != null) {
      if (controller.value.isRecordingVideo) {
        try {
          await controller.stopVideoRecording();
        } catch (_) {}
      }
      _isRecording = false;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      await CameraService.instance.release();
      _controller = null;
    } else if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pausePreview();
      } catch (_) {}
    }
  }

  Future<void> _handleAppLifecycleResumed() async {
    if (Platform.isIOS || Platform.isMacOS) {
      _initializeControllerFuture = _setupCamera();
      if (mounted) setState(() {});
      return;
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.resumePreview();
        await _applyFlashMode();
        return;
      } catch (_) {
        // fallback to full reinitialisation
      }
    }
    _initializeControllerFuture = _setupCamera();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isIOS) {
      unawaited(CameraService.instance.release());
      _controller = null;
    } else {
      try {
        _controller?.pausePreview();
      } catch (_) {}
    }
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
    if (!mounted) return;
    Navigator.pop(context, _isVideoMode);
  }

  Future<void> _openExplorer() async {
    if (_isRecording || _isBusy) return;
    context.read<TabNavigationModel>().jumpTo(1);
    await _handleBackNavigation();
  }

  Future<void> _switchMode(bool video) async {
    if (_isVideoMode == video) return;
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
          final filename = await widget.requestFilename(
            true,
            reserve: true,
          );
          setState(() => _currentFilename = filename);
          final videoFile = await controller.stopVideoRecording();
          final savedFile = File(videoFile.path);
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
        final filename = await widget.requestFilename(
          false,
          reserve: true,
        );
        setState(() => _currentFilename = filename);
        final image = await controller.takePicture();
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleBackNavigation();
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
              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    _buildTopBar(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildCameraPreview()),
                    _buildBottomControls(),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    String description = context.tr(
      de: 'Kamera konnte nicht gestartet werden.',
      en: 'The camera could not be started.',
    );
    if (error is CameraException && error.code == 'notfound') {
      description = context.tr(
        de: 'Keine Kamera verfügbar. Diese Funktion benötigt ein physisches Gerät.',
        en: 'No camera available. This feature requires a physical device.',
      );
    } else if (error != null) {
      description = '$description\n$error';
    }

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
            description,
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
            child: Text(
              context.tr(de: 'Erneut versuchen', en: 'Try again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back,
            tooltip: context.tr(de: 'Zurück', en: 'Back'),
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
          const SizedBox(width: 12),
          AnimatedOpacity(
            opacity: _isRecording ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: _isRecording
                ? const Icon(Icons.fiber_manual_record, color: Colors.red)
                : const SizedBox(width: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RoundIconButton(
            icon: Icons.photo_library_outlined,
            tooltip: context.tr(de: 'Galerie öffnen', en: 'Open gallery'),
            onPressed: _openExplorer,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildModeSelector(),
                const SizedBox(height: 16),
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
              ],
            ),
          ),
          _RoundIconButton(
            icon: _flashIconForMode(_flashMode),
            tooltip: _flashTooltip(context, _flashMode),
            onPressed: () {
              unawaited(_cycleFlashMode());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final options = [
      {
        'label': context.tr(de: 'Foto', en: 'Photo'),
        'isVideo': false,
      },
      {
        'label': context.tr(de: 'Video', en: 'Video'),
        'isVideo': true,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isVideo = option['isVideo'] as bool;
          final isSelected = _isVideoMode == isVideo;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _switchMode(isVideo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  option['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _flashIconForMode(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_auto;
    }
  }

  String _flashTooltip(BuildContext context, FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return context.tr(de: 'Blitz: Aus', en: 'Flash: Off');
      case FlashMode.always:
        return context.tr(de: 'Blitz: An', en: 'Flash: On');
      default:
        return context.tr(de: 'Blitz: Auto', en: 'Flash: Auto');
    }
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

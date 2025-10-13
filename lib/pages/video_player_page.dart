import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerPage extends StatefulWidget {
  final File videoFile;

  const VideoPlayerPage({super.key, required this.videoFile});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.file(widget.videoFile);
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.lightGreen,
          handleColor: Colors.lightGreenAccent,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Fehler beim Initialisieren des VideoPlayers: $e');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video abspielen'),
      ),
      body: Center(
        child: _isInitialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(color: Colors.lightGreen),
      ),
    );
  }
}

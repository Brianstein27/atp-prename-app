import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullscreenImagePage extends StatelessWidget {
  final File imageFile;
  final String displayName;

  const FullscreenImagePage({
    super.key,
    required this.imageFile,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          displayName,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(imageFile),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}

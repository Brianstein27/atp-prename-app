import 'package:atp_prename_app/pages/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <<< HIER FEHLTE DER WICHTIGE IMPORT
// import 'package:atp_prename_app/pages/home_page.dart';
import 'package:atp_prename_app/utils/album_manager.dart';

void main() {
  // Stellen Sie sicher, dass die Flutter-Bindungen initialisiert sind,
  // bevor Sie native Methoden (wie z.B. für photo_manager) aufrufen.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AlbumManager()..loadAlbums(),
      child: const FotoApp(),
    ),
  );
}

class FotoApp extends StatelessWidget {
  const FotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foto Naming App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

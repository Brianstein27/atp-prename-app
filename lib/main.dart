import 'package:atp_prename_app/pages/main_screen.dart';
import 'package:atp_prename_app/utils/album_manager.dart';
import 'package:atp_prename_app/utils/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  // Stellen Sie sicher, dass die Flutter-Bindungen initialisiert sind,
  // bevor Sie native Methoden (wie z.B. für photo_manager) aufrufen.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AlbumManager()..loadAlbums(),
        ),
        ChangeNotifierProvider(
          create: (context) => ThemeProvider()..loadThemeMode(),
        ),
      ],
      child: const FotoApp(),
    ),
  );
}

class FotoApp extends StatelessWidget {
  const FotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    const seedColor = Color(0xFF2E7D32);
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Foto Naming App',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode,
      theme: ThemeData(
        colorScheme: lightScheme,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

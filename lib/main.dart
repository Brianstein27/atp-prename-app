import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <<< HIER FEHLTE DER WICHTIGE IMPORT
import 'package:atp_prename_app/pages/home_page.dart';
import 'package:atp_prename_app/utils/album_manager.dart';

void main() {
  // Stellt sicher, dass Widgets gebunden sind, bevor Dienste gestartet werden
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Der AlbumManager wird hier über den gesamten Widget-Baum gelegt.
    return ChangeNotifierProvider(
      create: (context) => AlbumManager(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Foto App',
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

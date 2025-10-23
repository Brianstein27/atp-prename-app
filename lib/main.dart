import 'package:atp_prename_app/pages/main_screen.dart';
import 'package:atp_prename_app/utils/album_manager.dart';
import 'package:atp_prename_app/utils/theme_provider.dart';
import 'package:atp_prename_app/utils/subscription_provider.dart';
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
        ChangeNotifierProvider(
          create: (context) => SubscriptionProvider()..load(),
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
        scaffoldBackgroundColor: const Color(0xFFF4F6F2),
        fontFamily: 'Inter',
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: lightScheme.onPrimary,
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: lightScheme.onPrimary,
          unselectedLabelColor: lightScheme.onPrimary.withOpacity(0.7),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.white, width: 3),
            insets: EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: lightScheme.primary,
          contentTextStyle: TextStyle(color: lightScheme.onPrimary),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightScheme.outlineVariant),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(
              lightScheme.surfaceVariant,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF151D16),
        fontFamily: 'Inter',
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1C281D),
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: darkScheme.onSurface,
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: darkScheme.onSurface,
          unselectedLabelColor: darkScheme.onSurfaceVariant,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: darkScheme.secondary, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkScheme.primaryContainer,
          foregroundColor: darkScheme.onPrimaryContainer,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkScheme.primaryContainer,
          contentTextStyle: TextStyle(color: darkScheme.onPrimaryContainer),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF212D23),
          shadowColor: Colors.black45,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF273429),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.outlineVariant),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(
              const Color(0xFF212D23),
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return darkScheme.primary;
            }
            return darkScheme.onSurfaceVariant;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return darkScheme.primary.withOpacity(0.45);
            }
            return const Color(0xFF2C3A2F);
          }),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

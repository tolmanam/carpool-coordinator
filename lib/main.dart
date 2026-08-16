import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/database_service.dart';
import 'services/matrix_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = DatabaseService();
  await dbService.initDatabase();

  final matrixService = MatrixService(dbService: dbService);
  await matrixService.loadSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DatabaseService>.value(value: dbService),
        ChangeNotifierProvider<MatrixService>.value(value: matrixService),
      ],
      child: const CarpoolApp(),
    ),
  );
}

class CarpoolApp extends StatelessWidget {
  const CarpoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carpool Coordinator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: Consumer<MatrixService>(
        builder: (context, matrix, _) {
          if (matrix.isLoggedIn) {
            return const MainTabScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

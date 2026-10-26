import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'store.dart';

final AppStore store = AppStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const CsApp());
}

class CsApp extends StatelessWidget {
  const CsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CS Mobile App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E8C)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) =>
            store.current == null ? const AuthScreen() : const HomeScreen(),
      ),
    );
  }
}

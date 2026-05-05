import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'navigation/bottom_nav.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_manager.dart';
import 'services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    debugPrint("Firebase init failed: $e (This is expected if google-services.json is missing)");
  }
  
  runApp(const MyApp());

  // Initialize auth and negotiate JWT asynchronously so it doesn't block startup
  Future.microtask(() async {
    try {
      await BackendService.initialize();
      final backend = BackendService();
      await backend.registerDevice();
    } catch (e) {
      debugPrint("Backend init failed: \$e");
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ReClaim',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const BottomNav(),
        );
      },
    );
  }
}


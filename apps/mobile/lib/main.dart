import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'navigation/bottom_nav.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_manager.dart';
import 'services/backend_service.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  
  runApp(const MyApp());

  // Initialize auth and negotiate JWT asynchronously
  Future.microtask(() async {
    try {
      await BackendService.initialize();
      final backend = BackendService();
      await backend.registerDevice();
      
      // Initial session check
      await AuthService().refreshSession();
    } catch (e) {
      debugPrint("Initial init failed: $e");
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check JWT expiry and refresh on resume
      _auth.refreshSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeManager.themeMode,
          builder: (context, mode, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'ReClaim',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: _auth.currentUser == null 
                ? const LoginScreen() 
                : const BottomNav(),
            );
          },
        );
      },
    );
  }
}


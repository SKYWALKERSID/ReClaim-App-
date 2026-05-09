import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();

  User? _currentUser;
  User? get currentUser => _currentUser;

  AuthService._internal() {
    ApiService.onUnauthorized = logout;
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  int _failureCount = 0;
  DateTime? _lockoutUntil;

  Future<void> loginWithGoogle() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final seconds = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      throw Exception('Too many attempts. Please try again in $seconds seconds.');
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final dynamic googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken != null) {
        final response = await _api.dio.post('/auth/login', data: {
          'idToken': idToken,
          'deviceId': 'emulator_fixed_id',
        });

        await _api.saveTokens(response.data['accessToken'], response.data['refreshToken']);
        _failureCount = 0;
        _lockoutUntil = null;
      }
    } catch (e) {
      _failureCount++;
      if (_failureCount >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failureCount = 0; // Reset counter for next cycle after lockout
      }
      debugPrint("Auth Error: $e");
      throw Exception('Invalid email or password');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _api.getRefreshToken();
      if (refreshToken != null) {
        await _api.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    
    await _api.clearTokens();
    await _auth.signOut();
    await _googleSignIn.signOut();
    notifyListeners();
  }

  Future<void> refreshSession() async {
    final refreshToken = await _api.getRefreshToken();
    if (refreshToken == null) return;

    try {
      final response = await _api.dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken
      });
      await _api.saveTokens(response.data['accessToken'], response.data['refreshToken']);
    } catch (e) {
      await logout();
    }
  }
}

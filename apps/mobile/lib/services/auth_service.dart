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
  
  bool _isGuest = false;
  bool get isGuest => _isGuest;

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

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
        _failureCount = 0; 
      }
      debugPrint("Auth Error: $e");
      
      if (e is FirebaseAuthException) {
        throw Exception(e.message ?? 'Google Sign-In failed.');
      }
      
      if (e.toString().contains('network_error')) {
        throw Exception('Network connection failed. Check your internet.');
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final idToken = await credential.user?.getIdToken();
      if (idToken != null) {
        final response = await _api.dio.post('/auth/login', data: {
          'idToken': idToken,
          'deviceId': 'emulator_fixed_id',
        });
        await _api.saveTokens(response.data['accessToken'], response.data['refreshToken']);
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception(e.message ?? 'An unknown authentication error occurred.');
      }
      throw Exception('Email login failed: ${e.toString()}');
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await loginWithEmail(email, password);
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception(e.message ?? 'Signup failed. Please try again.');
      }
      throw Exception('Signup failed: ${e.toString()}');
    }
  }

  Future<void> loginWithApple() async {
    // TODO: Apple Sign-In requires Apple Developer enrollment and entitlement configuration.
    // See: https://pub.dev/packages/sign_in_with_apple
    throw UnimplementedError('Apple Sign-In is not yet configured for this project.');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString().split(':').last.trim()}');
    }
  }

  Future<void> verifyCurrentPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user is currently signed in.');
    }

    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      throw Exception('Incorrect password. Verification failed.');
    }
  }

  Future<void> continueAsGuest() async {
    try {
      final credential = await _auth.signInAnonymously();
      final idToken = await credential.user?.getIdToken();
      if (idToken != null) {
        final response = await _api.dio.post('/auth/login', data: {
          'idToken': idToken,
          'deviceId': 'emulator_fixed_id',
        });
        await _api.saveTokens(response.data['accessToken'], response.data['refreshToken']);
      }
      _isGuest = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Guest Login Error: $e");
      // Fallback to local guest mode if Firebase/Backend fails
      _isGuest = true;
      notifyListeners();
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
    _isGuest = false;
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

  Future<bool> sendRecoveryOTP(String email) async {
    try {
      await _api.dio.post('/auth/otp/send', data: {'email': email});
      return true;
    } catch (e) {
      debugPrint('Failed to send OTP: ${e.toString()}');
      return false;
    }
  }

  Future<bool> verifyRecoveryOTP(String email, String otp) async {
    try {
      await _api.dio.post('/auth/otp/verify', data: {'email': email, 'otp': otp});
      return true;
    } catch (e) {
      debugPrint('Invalid or expired OTP: ${e.toString()}');
      return false;
    }
  }
}

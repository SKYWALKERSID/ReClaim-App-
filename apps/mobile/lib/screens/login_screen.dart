import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _isLoading = false;
  static const _securityChannel = MethodChannel('com.reclaim/security');

  @override
  void initState() {
    super.initState();
    _enableSecurity();
  }

  @override
  void dispose() {
    _disableSecurity();
    super.dispose();
  }

  Future<void> _enableSecurity() async {
    try {
      await _securityChannel.invokeMethod('enableSecureWindow');
    } catch (_) {}
  }

  Future<void> _disableSecurity() async {
    try {
      await _securityChannel.invokeMethod('disableSecureWindow');
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _auth.loginWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_rounded, size: 80, color: Colors.indigoAccent),
                const SizedBox(height: 24),
                Text(
                  'ReClaim',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digital Wellbeing Enforcement',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 64),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _handleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 2,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Secure RS256 Authentication Enabled',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

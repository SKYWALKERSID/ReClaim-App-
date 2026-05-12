import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'safecode_recovery_screen.dart';

class SafeCodeSetupScreen extends StatefulWidget {
  final Function(String) onComplete;
  const SafeCodeSetupScreen({super.key, required this.onComplete});

  @override
  State<SafeCodeSetupScreen> createState() => _SafeCodeSetupScreenState();
}

class _SafeCodeSetupScreenState extends State<SafeCodeSetupScreen> {
  String _pin = "";
  final int _pinLength = 4;

  void _onKeyPress(String value) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += value;
      });
      if (_pin.length == _pinLength) {
        // Mock delay for success feel
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onComplete(_pin);
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Header Glow
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Text(
                  'SAFECODE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 60),
                const Text(
                  'Enter 4-digit code',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 40),
                
                // PIN Entry Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    bool isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 52,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFilled ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                          width: isFilled ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isFilled ? 14 : 10,
                          height: isFilled ? 14 : 10,
                          decoration: BoxDecoration(
                            color: isFilled ? Colors.white : Colors.white12,
                            shape: BoxShape.circle,
                            boxShadow: isFilled ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 10,
                              )
                            ] : [],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _showForgotPinDialog,
                  child: const Text('Forgot PIN', style: TextStyle(color: Colors.white38, fontSize: 14)),
                ),
                
                const Spacer(),
                
                // Numeric Keypad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      const SizedBox(height: 30),
                      _buildKeyRow(['4', '5', '6']),
                      const SizedBox(height: 30),
                      _buildKeyRow(['7', '8', '9']),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSpecialKey(Icons.face_unlock_rounded, () {}),
                          _buildNumberKey('0'),
                          _buildSpecialKey(Icons.backspace_outlined, _onBackspace),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPinDialog() async {
    final newPin = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SafeCodeRecoveryScreen()),
    );
    if (newPin != null && newPin is String) {
      widget.onComplete(newPin);
    }
  }

  void _onVerified() {
    setState(() => _pin = "");
    _showSnackBar('Identity verified. Please set a new PIN.', isSuccess: true);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: isSuccess ? Colors.green : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildKeyRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: numbers.map((n) => _buildNumberKey(n)).toList(),
    );
  }

  Widget _buildNumberKey(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(number),
        borderRadius: BorderRadius.circular(40),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        child: Container(
          width: 70,
          height: 70,
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        splashColor: Colors.white10,
        child: Container(
          width: 70,
          height: 70,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white70, size: 28),
        ),
      ),
    );
  }
}

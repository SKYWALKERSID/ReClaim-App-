import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import 'dart:ui';

class SafeCodeRecoveryScreen extends StatefulWidget {
  const SafeCodeRecoveryScreen({super.key});

  @override
  State<SafeCodeRecoveryScreen> createState() => _SafeCodeRecoveryScreenState();
}

class _SafeCodeRecoveryScreenState extends State<SafeCodeRecoveryScreen> {
  final AuthService _auth = AuthService();
  final BackendService _backend = BackendService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();

  int _step = 0; // 0: Email, 1: OTP, 2: New PIN
  bool _isLoading = false;
  String? _error;

  Future<void> _sendOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      if (email.isEmpty) throw "Please enter your email";
      
      // Hook into backend auth controller sendOTP
      final success = await _auth.sendRecoveryOTP(email);
      if (success) {
        setState(() => _step = 1);
      } else {
        throw "Failed to send OTP. Please try again.";
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final otp = _otpController.text.trim();
      if (otp.length < 6) throw "Enter a valid 6-digit OTP";
      
      final success = await _auth.verifyRecoveryOTP(_emailController.text.trim(), otp);
      if (success) {
        setState(() => _step = 2);
      } else {
        throw "Invalid or expired OTP";
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPIN() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pin = _newPinController.text.trim();
      if (pin.length != 4) throw "PIN must be 4 digits";
      
      // Save new PIN to backend
      final success = await _backend.saveUserSettings(
        "User", // Should ideally fetch name, but backend handles partial updates
        0, 
        safeCode: pin
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SafeCode recovered successfully!")),
          );
          Navigator.pop(context, pin);
        }
      } else {
        throw "Failed to update SafeCode";
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030307),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "RECOVER SAFECODE",
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            _buildProgressIndicator(),
            const SizedBox(height: 60),
            if (_step == 0) _buildEmailStep(),
            if (_step == 1) _buildOTPStep(),
            if (_step == 2) _buildPINStep(),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 64),
        const SizedBox(height: 24),
        const Text(
          "Identity Verification",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "We'll send a recovery code to your registered Gmail address.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_emailController, "Email Address", Icons.email_outlined),
        const SizedBox(height: 40),
        _buildActionButton("SEND RECOVERY CODE", _sendOTP),
      ],
    );
  }

  Widget _buildOTPStep() {
    return Column(
      children: [
        const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 64),
        const SizedBox(height: 24),
        const Text(
          "Verify OTP",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Check your inbox at ${_emailController.text}",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_otpController, "000000", Icons.password_rounded, maxLength: 6),
        const SizedBox(height: 40),
        _buildActionButton("VERIFY OTP", _verifyOTP),
      ],
    );
  }

  Widget _buildPINStep() {
    return Column(
      children: [
        const Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B), size: 64),
        const SizedBox(height: 24),
        const Text(
          "New SafeCode",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Set a new 4-digit emergency code.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_newPinController, "••••", Icons.lock_outline_rounded, maxLength: 4, obscure: true),
        const SizedBox(height: 40),
        _buildActionButton("RECOVER ACCESS", _resetPIN),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int? maxLength, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        obscureText: obscure,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
        decoration: InputDecoration(
          counterText: "",
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
    );
  }
}

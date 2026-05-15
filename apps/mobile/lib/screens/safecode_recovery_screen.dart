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

  @override
  void initState() {
    super.initState() ;
    // Force hide any residual overlays when entering recovery to prevent blocking
    _backend.hideBlockingOverlay();
  }

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
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
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
      if (pin.length < 4) throw "SafeCode must be at least 4 characters";
      
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "RECOVER SAFECODE",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildProgressIndicator(),
                  const SizedBox(height: 60),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _step == 0 
                      ? _buildEmailStep() 
                      : _step == 1 
                        ? _buildOTPStep() 
                        : _buildPINStep(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!, 
                              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
              color: isActive ? AppColors.primary : AppColors.primary.withOpacity(0.08),
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
        Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 64),
        const SizedBox(height: 24),
        Text(
          "Identity Verification",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "We'll send a recovery code to your registered Gmail address.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_emailController, "Email Address", Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 40),
        _buildActionButton("SEND RECOVERY CODE", _sendOTP),
      ],
    );
  }

  Widget _buildOTPStep() {
    return Column(
      children: [
        Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 64),
        const SizedBox(height: 24),
        Text(
          "Verify OTP",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Check your inbox at ${_emailController.text}",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_otpController, "000000", Icons.password_rounded, maxLength: 6,
            keyboardType: TextInputType.number),
        const SizedBox(height: 40),
        _buildActionButton("VERIFY OTP", _verifyOTP),
      ],
    );
  }

  Widget _buildPINStep() {
    return Column(
      children: [
        Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B), size: 64),
        const SizedBox(height: 24),
        Text(
          "New SafeCode",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Set a new 4-digit emergency code.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
        ),
        const SizedBox(height: 40),
        _buildTextField(_newPinController, "Enter new SafeCode", Icons.lock_outline_rounded,
            maxLength: 4, obscure: true, keyboardType: TextInputType.number),
        const SizedBox(height: 40),
        _buildActionButton("RECOVER ACCESS", _resetPIN),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int? maxLength,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.textPrimary, 
          fontSize: 18, 
          letterSpacing: (keyboardType == TextInputType.number || keyboardType == TextInputType.phone) ? 4 : 0.5, 
          fontWeight: FontWeight.w600
        ),
        decoration: InputDecoration(
          counterText: "",
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.15), fontSize: 16, letterSpacing: 1),
          prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: -5,
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textPrimary))
              : Text(
                  label, 
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                ),
          ),
        ),
      ),
    );
  }
}


import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../attendance_dashboard.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _empCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  XFile? _selfie;
  bool _loading = false;
  int _retrySeconds = 0;
  Timer? _retryTimer;

  // Transgulf Brand Identity Colors
  static const Color brandDarkBlue = Color(0xFF002D5B);
  static const Color brandOrange = Color(0xFFF05A28);
  static const Color bgSoftGrey = Color(0xFFF4F7F9);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _empCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickSelfie() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (img != null) setState(() => _selfie = img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selfie == null) {
      _showError('Identification selfie is required for registration.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await AuthService().signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        employeeId: _empCtrl.text.trim(),
        avatarPath: _selfie?.path,
      );

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceDashboard()),
        );
      }
    } catch (e) {
      final s = e.toString().toLowerCase();
      final match = RegExp(r'retry-after:\s*(\d+)').firstMatch(s);
      if (match != null) {
        _startRetryCountdown(int.parse(match.group(1)!));
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startRetryCountdown(int seconds) {
    _retryTimer?.cancel();
    setState(() => _retrySeconds = seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_retrySeconds <= 1) {
        timer.cancel();
        setState(() => _retrySeconds = 0);
      } else {
        setState(() => _retrySeconds -= 1);
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: brandDarkBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "REGISTRATION",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: brandDarkBlue,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSelfiePicker(),
              const SizedBox(height: 30),
              _buildTextField(_nameCtrl, "Full Name", Icons.person_outline),
              _buildTextField(_empCtrl, "Employee ID", Icons.badge_outlined),
              _buildTextField(_emailCtrl, "Work Email", Icons.email_outlined),
              _buildTextField(_passCtrl, "Password", Icons.lock_outline, isPass: true),
              _buildTextField(_confirmCtrl, "Confirm Password", Icons.lock_reset_outlined, isPass: true, isLast: true),
              
              const SizedBox(height: 30),
              
              if (_retrySeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Security cooldown: $_retrySeconds s",
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_loading || _retrySeconds > 0) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandDarkBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _retrySeconds > 0 ? "COOLDOWN ACTIVE" : "CREATE ACCOUNT",
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelfiePicker() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: brandOrange, width: 3),
                boxShadow: [
                  BoxShadow(color: brandDarkBlue.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: bgSoftGrey,
                backgroundImage: _selfie != null ? FileImage(File(_selfie!.path)) : null,
                child: _selfie == null
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _pickSelfie,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: brandOrange, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Identity Verification Photo",
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: brandDarkBlue.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl, 
    String label, 
    IconData icon, 
    {bool isPass = false, bool isLast = false}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        validator: (val) => val!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: brandDarkBlue, size: 22),
          filled: true,
          fillColor: bgSoftGrey,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: brandOrange, width: 1.5),
          ),
        ),
      ),
    );
  }
}
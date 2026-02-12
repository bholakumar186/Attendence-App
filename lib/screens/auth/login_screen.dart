import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import '../attendance_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../../services/supabase_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _isPasswordVisible = false;

  // Transgulf Brand Identity Colors
  static const Color brandDarkBlue = Color(0xFF002D5B); // Deep Corporate Blue
  static const Color brandOrange = Color(0xFFF05A28); // Energy Orange
  static const Color bgSoftGrey = Color(0xFFF4F7F9);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 1. Perform Authentication
      final user = await AuthService().signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      if (user != null) {
        if (!mounted) return;

        // 2. Fetch User Profile/Role immediately after login
        // Assuming SupabaseService has getProfile(userId)
        final profile = await SupabaseService().getProfile(user.id);
        final String role = (profile?['role'] ?? 'employee')
            .toString()
            .toLowerCase();

        if (!mounted) return;

        // 3. Role-Based Navigation
        if (role == 'admin' || role == 'superadmin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminDashboard(),
            ), // Admin starts at the logs
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AttendanceDashboard(),
            ), // Employees start at dashboard
          );
        }
      } else {
        _showError('Invalid email or password.');
      }
    } catch (e) {
      String errorMessage = "An unexpected error occurred.";
      if (e.toString().contains('user-not-found') ||
          e.toString().contains('wrong-password')) {
        errorMessage = "Invalid credentials. Please try again.";
      } else {
        errorMessage = e.toString();
      }
      _showError(errorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSoftGrey,
      body: Stack(
        children: [
          _buildBackgroundDesign(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 30),
                  _buildLoginCard(),
                  const SizedBox(height: 20),
                  // _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDesign() {
    return Positioned(
      top: -100,
      right: -100,
      child: CircleAvatar(
        radius: 150,
        backgroundColor: brandDarkBlue.withOpacity(0.05),
      ),
    );
  }

   Widget _buildLogoSection() {
  return Column(
    children: [
      Image.asset(
        'assets/images/company_logo.png',
        height: 90,          // 🔹 control logo size here
        width: 90,
        fit: BoxFit.contain, // keeps aspect ratio
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.business,
            size: 60,
            color: brandDarkBlue,
          );
        },
      ),

      const SizedBox(height: 16),

      Text(
        "TRANSGULF",
        style: GoogleFonts.montserrat(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: brandDarkBlue,
          letterSpacing: 2,
        ),
      ),
      Text(
        "GLOBAL POWER LIMITED",
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: brandDarkBlue.withOpacity(0.7),
          letterSpacing: 4,
        ),
      ),
    ],
  );
}

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Employee Login",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: brandDarkBlue,
              ),
            ),
            const SizedBox(height: 25),

            // Email Field
            _buildInputField(
              controller: _emailCtrl,
              label: "Email",
              icon: Icons.alternate_email,
              validator: (val) => val!.isEmpty ? "Enter your email" : null,
            ),
            const SizedBox(height: 18),

            // Password Field
            _buildInputField(
              controller: _passCtrl,
              label: "Password",
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (val) => val!.length < 6 ? "Password too short" : null,
            ),

            const SizedBox(height: 30),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandDarkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "LOGIN TO DASHBOARD",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: brandDarkBlue, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: brandOrange, width: 2),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          ),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(color: Colors.black54, fontSize: 14),
              children: [
                TextSpan(text: "Don't have an account? "),
                TextSpan(
                  text: "Register here",
                  style: TextStyle(
                    color: brandOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "© 2026 Transgulf Global Power Ltd.",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

}

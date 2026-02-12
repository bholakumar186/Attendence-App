import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Transgulf Colors
  static const Color brandDarkBlue = Color(0xFF002D5B);
  static const Color brandOrange = Color(0xFFF05A28);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    // Navigate to Login after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandDarkBlue,
      body: Stack(
        children: [
          // Background Decorative Element (Optional subtle gradient)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [brandDarkBlue.withValues(alpha: 0.8), brandDarkBlue],
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Logo Container
                  Image.asset(
                    'assets/images/company_logo.png',
                    height: 120, // adjust size freely
                    width: 120,
                    fit: BoxFit.contain, // keeps logo proportions
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.business,
                        size: 70,
                        color: brandOrange,
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  Text(
                    "TRANSGULF",
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  Text(
                    "GLOBAL POWER LIMITED",
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: brandOrange,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "SECURE INTERNAL CONNECTION",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

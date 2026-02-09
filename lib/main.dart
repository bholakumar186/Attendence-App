import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure these paths match your actual folder structure
import 'screens/attendance_dashboard.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: 'https://vynbeaemkpiiwqjocqcc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5bmJlYWVta3BpaXdxam9jcWNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwMTE5ODAsImV4cCI6MjA4NTU4Nzk4MH0.4c4BS7Ro7bw6yd71T1zq7_p25f5JGsFfrP2BVbOoVHM',
  );

  final session = Supabase.instance.client.auth.currentSession;
print('Restored session: $session');


  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transgulf Portal',
      theme: ThemeData(
        // Using the Transgulf brand color as the seed
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF002D5B),
          primary: const Color(0xFF002D5B),
          secondary: const Color(0xFFF05A28),
        ),
        useMaterial3: true,
      ),
      // The app starts at the Splash Screen
      home: const SplashScreen(),
    );
  }
}

/// The AuthGate determines if the user needs to log in or go to the Dashboard.
/// This is called automatically after the SplashScreen timer ends.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        } else {
          return const AttendanceDashboard();
        }
      },
    );
  }
}


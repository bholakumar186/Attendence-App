import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final _client = Supabase.instance.client;

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    String? avatarPath,
    int maxRetries = 3,
  }) async {
    try {
      final res = await _retryWithBackoff(
        () => _client.auth.signUp(email: email, password: password),
        maxRetries: maxRetries,
      );

      final user = res.user;
      if (user == null) {
        throw Exception('Signup failed or confirmation required');
      }

      String? avatarUrl;
      if (avatarPath != null) {
        avatarUrl = await SupabaseService().uploadAvatar(user.id, avatarPath);
      }

      // Insert profile row (create or update)
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'employee_id': employeeId,
        'avatar_url': avatarUrl,
      }).maybeSingle();

      return user;
    } catch (e) {
      if (_isRateLimitError(e)) {
        throw Exception(
          'Too many requests. Email sending rate limit exceeded. Please wait a minute and try again.',
        );
      }
      throw Exception('Sign up failed: $e');
    }
  }

  /// Generic retry wrapper with exponential backoff + jitter.
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    final random = Random();

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (!_isRateLimitError(e) || attempt > maxRetries) rethrow;

        final delayMillis =
            (pow(2, attempt) * 1000).toInt() + random.nextInt(1000);
        await Future.delayed(Duration(milliseconds: delayMillis));
      }
    }
  }

  bool _isRateLimitError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('429') ||
        s.contains('rate limit') ||
        s.contains('too many requests');
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}

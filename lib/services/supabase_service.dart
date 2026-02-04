import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


class SupabaseService {
  final _client = Supabase.instance.client;

  Future<void> saveAttendanceRecord({
    required String employeeId,
    required double lat,
    required double lng,
    required String status,
  }) async {
    try {
      final String point = 'POINT($lng $lat)';
      await _client.from('attendance_logs').insert({
        'employee_id': employeeId,
        'location': point,
        'status': status,
        'device_info': 'Device',
      });
      print("✅ Record synced to cloud.");
    } catch (e) {
      throw Exception("Cloud Sync Failed: $e");
    }
  }

  /// Fetch the user's profile by combining `employees` (role, employee_id)
  /// and `profiles` (full_name, avatar_url, etc.). This ensures role is
  /// available for role-based UI (e.g., admin features).
  /// Fetch user profile from `employees` table only
Future<Map<String, dynamic>?> getProfile(String userId) async {
  try {
    final res = await _client
        .from('employees')
        .select()
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;

    return Map<String, dynamic>.from(res as Map);
  } catch (e) {
    return null;
  }
}

  /// Upload avatar to the 'avatars' storage bucket and return public url
  Future<String?> uploadAvatar(String userId, String filePath) async {
    try {
      final bucket = _client.storage.from('avatars');
      final fileName = 'user_$userId.jpg';
      final file = File(filePath);
      await bucket.upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      final url = bucket.getPublicUrl(fileName);
      return url.toString();
    } catch (e) {
      return null;
    }
  }

  /// Fetch recent attendance logs for an employee
  Future<List<dynamic>> fetchAttendanceRecords(String employeeId) async {
    try {
      final res = await _client
          .from('attendance_logs')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      return res as List<dynamic>? ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch today's attendance row from the canonical `attendance` table
  Future<Map<String, dynamic>?> fetchTodayAttendance(String employeeId) async {
    try {
      final res = await _client
          .from('attendance')
          .select()
          .eq('employee_id', employeeId)
          .eq('date', DateTime.now().toUtc().toIso8601String().split('T').first)
          .limit(1)
          .single();
      return res as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Count distinct days with an 'IN' status
  Future<int> getPresentDaysCount(String employeeId) async {
    try {
      final logs = await fetchAttendanceRecords(employeeId);
      final days = <String>{};
      for (final row in logs) {
        if (row['status']?.toString().toUpperCase() != 'IN') continue;
        final created = row['created_at'];
        if (created == null) continue;
        final date = DateTime.parse(
          created.toString(),
        ).toIso8601String().split('T').first;
        days.add(date);
      }
      return days.length;
    } catch (e) {
      return 0;
    }
  }

  /// Placeholder for face verification
  /// In production call your backend or 3rd-party face-match API
  Future<bool> verifyFaceMatch(String imagePath, String userId) async {
    // TODO: Implement secure server-side face verification
    // For now, we accept the selfie (you must replace this with proper verification)
    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }

  /// Mark IN attendance using a secure RPC (server side function)
  /// Updated Mark IN attendance
  Future<Map<String, dynamic>> markAttendanceIn({
    required String employeeId,
    required double lat,
    required double lng,
    String? deviceInfo,
  }) async {
    try {
      // 1. Remove .execute()
      // 2. The result is returned directly
      final res = await _client.rpc(
        'mark_attendance_in',
        params: {
          'p_employee_id': employeeId,
          'p_lat': lat,
          'p_lng': lng,
          'p_device_info': deviceInfo ?? 'mobile',
        },
      );

      return {'success': true, 'data': res};
    } catch (e) {
      // In the new version, errors are thrown and caught here
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Updated Mark OUT attendance
  Future<Map<String, dynamic>> markAttendanceOut({
    required String employeeId,
    required double lat,
    required double lng,
    String? deviceInfo,
  }) async {
    try {
      final res = await _client.rpc(
        'mark_attendance_out',
        params: {
          'p_employee_id': employeeId,
          'p_lat': lat,
          'p_lng': lng,
          'p_device_info': deviceInfo ?? 'mobile',
        },
      );

      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch monthly attendance summary via RPC
  /// Fetch monthly attendance summary via RPC
  Future<Map<String, dynamic>> fetchMonthlySummary({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    try {
      // 1. Remove .execute()
      // 2. The result is now the data itself, or it throws an exception on error
      final res = await _client.rpc(
        'monthly_attendance_summary',
        params: {'p_employee_id': employeeId, 'p_year': year, 'p_month': month},
      );

      return {'success': true, 'data': res};
    } catch (e) {
      // Errors (like network or SQL issues) are caught here
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Admin-only: Request backend to create a new employee (server must use service role key)
  /// This calls your external admin API (Node/Edge function). Provide ADMIN_API_URL in env
  Future<Map<String, dynamic>> createEmployeeViaAdmin({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
    required String adminApiUrl,
    required String adminApiKey,
  }) async {
    // Calls your protected admin endpoint which uses the Supabase service role key

    // Quick validation to catch common client mistakes (missing scheme, empty URL)
    if (adminApiUrl.trim().isEmpty) {
      return {'success': false, 'message': 'Admin API URL is required.'};
    }
    final url = adminApiUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return {
        'success': false,
        'message': 'Admin API URL must start with http:// or https://',
      };
    }

    try {
      final uri = Uri.parse('$url/admin/create-employee');
      final headers = {
        'Content-Type': 'application/json',
        'x-admin-api-key': adminApiKey,
      };
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role ?? 'employee',
      });

      // Helpful debug log for client-side troubleshooting
      debugPrint('Calling Admin API: $uri');

      final resp = await http.post(uri, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': 'Admin API error: ${resp.statusCode} ${resp.body}',
      };
    } catch (e, st) {
      // Include stack trace for richer debugging when running locally
      debugPrint('Admin API call failed: $e\n$st');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }
}

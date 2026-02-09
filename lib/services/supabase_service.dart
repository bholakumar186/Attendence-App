import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Future<String?> uploadAvatar(String userId, XFile imageFile) async {
    try {
      final bucket = _client.storage.from('avatars');
      final fileName = 'user_$userId.jpg';

      // Read bytes (works on mobile + web)
      final Uint8List bytes = await imageFile.readAsBytes();

      await bucket.uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = bucket.getPublicUrl(fileName);
      return url;
    } catch (e) {
      debugPrint('Upload avatar error: $e');
      return null;
    }
  }

  Future<List<dynamic>> fetchAttendanceRecords(String employeeId) async {
    try {
      final res = await _client
          .from('attendance')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      return res as List<dynamic>? ?? [];
    } catch (e) {
      return [];
    }
  }

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

  Future<bool> verifyFaceMatch(XFile imageFile, String userId) async {
    final client = Supabase.instance.client;
    try {
      // Step 1: Read file bytes
      Uint8List fileBytes = await imageFile.readAsBytes();

      if (fileBytes.isEmpty) {
        debugPrint("File is empty: ${imageFile.name}");
        return false;
      }

      // Step 2: Generate file name
      final fileName =
          'verify/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      debugPrint("Uploading file as $fileName");

      // Step 3: Upload to Supabase storage
      final uploadResponse = await client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      debugPrint("Upload Response: $uploadResponse");

      // Step 4: Call Supabase Edge Function for face verification
      final session = client.auth.currentSession;
      if (session == null) {
        debugPrint('User not logged in');
        return false;
      }
      final response = await client.functions.invoke(
        'verify-face',
        headers: {'Authorization': 'Bearer ${session!.accessToken}'},
        body: {'userId': userId, 'verifyImagePath': fileName},
      );

      debugPrint("Edge function response status: ${response.status}");
      debugPrint("Edge function response data: ${response.data}");

      // Step 5: Check response
      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final match = data['match'] == true;
        final confidence = (data['confidence'] ?? 0);
        debugPrint("Face match: $match, confidence: $confidence");
        return match && confidence > 50;
      } else {
        debugPrint("Face verification failed with status: ${response.status}");
        return false;
      }
    } catch (e, st) {
      debugPrint('Face Match Error: $e');
      debugPrint('$st');
      return false;
    }
  }

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

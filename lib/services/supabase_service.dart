import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:io';

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

  /// Fetch all attendance records (admin use)
  Future<List<dynamic>> fetchAllAttendance({int? limit, int? offset}) async {
    try {
      final query = _client
          .from('attendance')
          .select('*, employees(full_name, employee_id)')
          .order('created_at', ascending: false);

      if (limit != null) query.limit(limit);
      if (offset != null) query.range(offset, (offset + (limit ?? 100)) - 1);

      final res = await query;
      return res as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('fetchAllAttendance error: $e');
      return [];
    }
  }

  /// Fetch attendance in a date range (admin use)
  Future<List<dynamic>> fetchAttendanceByDateRange({
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    try {
      // 1. Format dates to ISO8601 strings (yyyy-MM-dd)
      final fromStr = DateFormat('yyyy-MM-dd').format(from);
      final String toStr = DateFormat('yyyy-MM-dd').format(to);

      // 2. Build the query
      // Note: Use 'employees!inner' if you want to ensure only records
      // with valid employee links are shown.
      var query = _client
          .from('attendance')
          .select('*, employees(full_name, employee_id)');

      // 3. Apply Filters
      query = query.gte('date', fromStr).lte('date', toStr);

      if (employeeId != null && employeeId.trim().isNotEmpty) {
        // Use 'eq' on the attendance table's employee_id
        query = query.eq('employee_id', employeeId.trim());
      }

      // 4. Order and Execute
      final List<Map<String, dynamic>> res = await query.order(
        'date',
        ascending: false,
      );

      return res;
    } catch (e) {
      // This will tell you if it's a "column not found" or "permission denied" error
      debugPrint('Supabase Error: $e');
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
      // Get the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(
        now.year,
        now.month,
        1,
      ).toIso8601String();

      // Fetch records only for this month to improve performance
      final res = await _client
          .from('attendance')
          .select('date')
          .eq('employee_id', employeeId)
          .gte('date', firstDayOfMonth);

      // Using a Set ensures we only count unique days
      // (in case there are multiple logs for one day)
      final List<dynamic> data = res as List<dynamic>;
      final uniqueDays = data.map((row) => row['date'].toString()).toSet();

      return uniqueDays.length;
    } catch (e) {
      debugPrint("Error counting present days: $e");
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
        final confidence = (data['similarity'] ?? 0);
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

  // Inside SupabaseService class
  Future<Map<String, dynamic>> createEmployeeViaAdmin({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
    required String adminApiUrl,
    required String adminApiKey,
    File? imageFile, // New Parameter
  }) async {
    try {
      String? photoUrl;
      String? fileName;

      // 1. Upload Photo to Bucket if exists
      if (imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(' ', '_')}.jpg';
        final path = 'profiles/$fileName';

        await Supabase.instance.client.storage
            .from('employee_photo')
            .upload(path, imageFile);

        // Get Public URL
        photoUrl = Supabase.instance.client.storage
            .from('employee_photo')
            .getPublicUrl(path);
      }

      // 2. Prepare API Call
      final uri = Uri.parse('${adminApiUrl.trim()}/admin/create-employee');
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role ?? 'employee',
        'reference_photo_url': photoUrl,
        'reference_photo': imageFile != null ? fileName : null,
      });

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-admin-api-key': adminApiKey,
        },
        body: body,
      );

      if (resp.statusCode == 200)
        return {'success': true, 'data': jsonDecode(resp.body)};
      return {'success': false, 'message': 'API error: ${resp.body}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Inside SupabaseService class
  Future<String?> updateEmployeePhoto(
    String employeeUuid,
    XFile imageFile,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Generate file name
      final fileName =
          'ref_${employeeUuid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final path = 'profiles/$fileName';

      // Upload with upsert
      await _client.storage
          .from('employee_photo')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url = _client.storage.from('employee_photo').getPublicUrl(path);

      // ✅ Update BOTH url and filename
      await _client
          .from('employees')
          .update({
            'reference_photo_url': url,
            'reference_photo': fileName, // ✅ Save filename
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', employeeUuid);

      return url;
    } catch (e) {
      debugPrint('Error updating photo: $e');
      return null;
    }
  }
}

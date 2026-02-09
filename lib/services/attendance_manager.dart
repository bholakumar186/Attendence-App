import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

class AttendanceManager {
  final double officeLat = 25.60305125;
  final double officeLng = 85.154024;
  final double allowedRadiusMeters = 50.0;

  final SupabaseService _supabaseService = SupabaseService();

  Future<Map<String, dynamic>> submitAttendance(String employeeId) async {
    try {
      Position position = await _determinePosition();
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );
      if (distance > allowedRadiusMeters) {
        return {
          "success": false,
          "message":
              "Out of bounds. You are ${distance.round()}m away from the office.",
        };
      }
      final today = await _supabaseService.fetchTodayAttendance(employeeId);
      if (today == null || today['in_time'] == null) {
        final res = await _supabaseService.markAttendanceIn(
          employeeId: employeeId,
          lat: position.latitude,
          lng: position.longitude,
        );
        if (res['success'] == true) {
          return {"success": true, "message": "IN marked successfully"};
        } else {
          return {
            "success": false,
            "message": res['message'] ?? 'Failed to mark IN.',
          };
        }
      } else if (today['out_time'] == null) {
        final res = await _supabaseService.markAttendanceOut(
          employeeId: employeeId,
          lat: position.latitude,
          lng: position.longitude,
        );

        if (res['success'] == true) {
          return {"success": true, "message": "OUT marked successfully"};
        } else {
          return {
            "success": false,
            "message": res['message'] ?? 'Failed to mark OUT.',
          };
        }
      } else {
        return {
          "success": false,
          "message": "Attendance already completed for today.",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString().replaceAll("Exception:", "").trim(),
      };
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services are disabled.';
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw 'Location permissions denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. Please enable them in settings.';
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}

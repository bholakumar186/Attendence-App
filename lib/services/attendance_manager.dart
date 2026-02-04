import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart'; // Ensure this import matches your file structure

class AttendanceManager {
  // Office Coordinates
  final double officeLat = 25.60305125;
  final double officeLng = 85.154024;
  final double allowedRadiusMeters = 50.0;

  // Initialize your Supabase service
  final SupabaseService _supabaseService = SupabaseService();

  /// Main function to mark attendance after face match
  Future<Map<String, dynamic>> submitAttendance(String employeeId) async {
    try {
      // 1. Get Current Location
      Position position = await _determinePosition();

      // 2. Calculate distance from Office
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );
      print("Distance from office: $distance meters");
      print("Current GPS: ${position.latitude}, ${position.longitude}");

      // 3. Geofence Validation
      if (distance > allowedRadiusMeters) {
        return {
          "success": false,
          "message":
              "Out of bounds. You are ${distance.round()}m away from the office.",
        };
      }

      // 4. Check today's attendance and call IN or OUT RPC accordingly
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
      // Catching errors from either Location or Supabase
      return {
        "success": false,
        "message": e.toString().replaceAll("Exception:", "").trim(),
      };
    }
  }

  /// Haversine formula to calculate distance in meters
  // double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  //   const p = 0.017453292519943295;
  //   final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
  //       cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  //   return 12742 * asin(sqrt(a)) * 1000;
  // }

  /// Ensure GPS is on and permissions are granted
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

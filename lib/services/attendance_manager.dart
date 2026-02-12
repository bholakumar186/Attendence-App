import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

/// Represents an office location configuration
class Office {
  final String name;
  final double lat;
  final double lng;

  Office({required this.name, required this.lat, required this.lng});
}

class AttendanceManager {
  // 1. Updated list with your specific coordinates
  final List<Office> _offices = [
    Office(
      name: "Main Office",
      lat: 25.60305125,
      lng: 85.154024,
    ),
    Office(
      name: "Secondary Office",
      lat: 25.599106,
      lng: 85.157534,
    ),
  ];

  final double allowedRadiusMeters = 50.0;
  final SupabaseService _supabaseService = SupabaseService();

  Future<Map<String, dynamic>> submitAttendance(String employeeId) async {
    try {
      final position = await _determinePosition();

      // 2. Identify which office the user is near
      Office? currentOffice;
      double minDistance = double.infinity;

      for (var office in _offices) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          office.lat,
          office.lng,
        );

        // Check if user is within the 50m radius of this specific office
        if (distance <= allowedRadiusMeters) {
          currentOffice = office;
          break; 
        }

        // Track the closest one for the error message if none match
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      // 3. Handle case where user is not at any registered office
      if (currentOffice == null) {
        return {
          "success": false,
          "message":
              "Out of bounds. You are ${minDistance.round()}m away from the nearest office.",
        };
      }

      final today = await _supabaseService.fetchTodayAttendance(employeeId);
      final now = DateTime.now();

      DateTime todayAt(int hour, int minute) =>
          DateTime(now.year, now.month, now.day, hour, minute);

      bool isWithin(DateTime start, DateTime end) =>
          now.isAtSameMomentAs(start) ||
          now.isAtSameMomentAs(end) ||
          (now.isAfter(start) && now.isBefore(end));

      // ------------------ PUNCH IN ------------------
      if (today == null || today['in_time'] == null) {
        final inStart = todayAt(9, 45);
        final inEnd = todayAt(20, 20);

        if (!isWithin(inStart, inEnd)) {
          return {
            "success": false,
            "message":
                "Punch-in allowed between ${formatTime(inStart)} and ${formatTime(inEnd)}.",
          };
        }

        final res = await _supabaseService.markAttendanceIn(
          employeeId: employeeId,
          lat: position.latitude,
          lng: position.longitude,
        );

        return res['success'] == true
            ? {"success": true, "message": "IN marked at ${currentOffice.name}"}
            : {
                "success": false,
                "message": res['message'] ?? 'Failed to mark IN.',
              };
      }

      // ------------------ PUNCH OUT ------------------
      if (today['out_time'] == null) {
        final outStart = todayAt(10, 00);
        final outEnd = todayAt(23, 59);

        if (!isWithin(outStart, outEnd)) {
          return {
            "success": false,
            "message":
                "Punch-out allowed between ${formatTime(outStart)} and ${formatTime(outEnd)}.",
          };
        }

        final res = await _supabaseService.markAttendanceOut(
          employeeId: employeeId,
          lat: position.latitude,
          lng: position.longitude,
        );

        return res['success'] == true
            ? {"success": true, "message": "OUT marked at ${currentOffice.name}"}
            : {
                "success": false,
                "message": res['message'] ?? 'Failed to mark OUT.',
              };
      }

      return {
        "success": false,
        "message": "Attendance already completed for today.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": e.toString().replaceAll("Exception:", "").trim(),
      };
    }
  }

  String formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
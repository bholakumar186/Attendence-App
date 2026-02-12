import 'package:intl/intl.dart';
import '../screens/admin/models/employee_monthly_report.dart';

class MonthlyReportService {
  List<EmployeeMonthlyReport> generateMonthlyReport({
    required List<dynamic> rawData,
    required int totalCompanyWorkingDays,
    required double baseSalary,
  }) {
    final Map<String, Map<String, dynamic>> employeeStats = {};

    for (final record in rawData) {
      final emp = record['employees'];
      if (emp == null) continue;

      final String empId = emp['employee_id'].toString();
      final String name = emp['full_name'] ?? "Unknown";
      final String? date = record['date'];

      if (date == null) continue;

      employeeStats.putIfAbsent(empId, () => {
            'name': name,
            'id': empId,
            'uniqueDates': <String>{},
            'totalMinutes': 0,
            'lateDays': 0,
          });

      employeeStats[empId]!['uniqueDates'].add(date);

      final checkIn = record['check_in'];
      final checkOut = record['check_out'];

      final parsedCheckIn = _safeParseTime(checkIn);
      final parsedCheckOut = _safeParseTime(checkOut);

      // Late logic (after 9:15 AM)
      if (parsedCheckIn != null &&
          (parsedCheckIn.hour > 9 ||
              (parsedCheckIn.hour == 9 && parsedCheckIn.minute > 15))) {
        employeeStats[empId]!['lateDays']++;
      }

      // Duration logic
      if (parsedCheckIn != null &&
          parsedCheckOut != null &&
          parsedCheckOut.isAfter(parsedCheckIn)) {
        employeeStats[empId]!['totalMinutes'] +=
            parsedCheckOut.difference(parsedCheckIn).inMinutes;
      }
    }

    return employeeStats.values.map((stats) {
      final int daysPresent = stats['uniqueDates'].length;
      final int totalMinutes = stats['totalMinutes'];

      final double dailyRate = baseSalary / totalCompanyWorkingDays;
      final double hourlyRate = dailyRate / 8;

      final double actualHours = totalMinutes / 60.0;
      final double standardHours = totalCompanyWorkingDays * 8.0;

      final double overtimeHours =
          actualHours > standardHours ? actualHours - standardHours : 0;

      final double overtimePay = overtimeHours * (hourlyRate * 1.5);
      final double earnedBase = daysPresent * dailyRate;
      final double lateDeduction = stats['lateDays'] * 5.0;

      final double netSalary =
          earnedBase + overtimePay - lateDeduction;

      return EmployeeMonthlyReport(
        id: stats['id'],
        name: stats['name'],
        daysPresent: daysPresent,
        lateDays: stats['lateDays'],
        totalHours: actualHours,
        overtimeHours: overtimeHours,
        netSalary: netSalary,
        attendanceRatio:
            (daysPresent / totalCompanyWorkingDays) * 100,
      );
    }).toList();
  }

  DateTime? _safeParseTime(String? time) {
    if (time == null) return null;
    try {
      return DateFormat("HH:mm:ss").parse(time);
    } catch (_) {
      return null;
    }
  }
}

class EmployeeMonthlyReport {
  final String id;
  final String name;
  final int daysPresent;
  final int lateDays;
  final double totalHours;
  final double overtimeHours;
  final double netSalary;
  final double attendanceRatio;

  EmployeeMonthlyReport({
    required this.id,
    required this.name,
    required this.daysPresent,
    required this.lateDays,
    required this.totalHours,
    required this.overtimeHours,
    required this.netSalary,
    required this.attendanceRatio,
  });
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../services/monthly_report_service.dart';
import './models/employee_monthly_report.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final SupabaseService _supa = SupabaseService();
  final MonthlyReportService _reportService = MonthlyReportService();

  DateTime _selectedMonth = DateTime.now();
  bool _loading = false;

  List<dynamic> _rawData = [];
  List<EmployeeMonthlyReport> _reportData = [];

  final TextEditingController _workingDaysController = TextEditingController(
    text: "22",
  );

  int _totalCompanyWorkingDays = 22;
  final double _baseSalary = 3000.0;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  @override
  void dispose() {
    _workingDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthlyData() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );

      _rawData = await _supa.fetchAttendanceByDateRange(
        from: firstDay,
        to: lastDay,
      );

      _recalculateReport();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load data")));
    }

    setState(() => _loading = false);
  }

  void _recalculateReport() {
    _reportData = _reportService.generateMonthlyReport(
      rawData: _rawData,
      totalCompanyWorkingDays: _totalCompanyWorkingDays,
      baseSalary: _baseSalary,
    );
  }

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _loadMonthlyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandDarkBlue = Color(0xFF002D5B);
    const brandOrange = Color(0xFFF05A28);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Monthly Report",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: brandDarkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(brandDarkBlue),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                ? const Center(child: Text("No data for this month"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reportData.length,
                    itemBuilder: (_, index) {
                      final item = _reportData[index];
                      return _buildEmployeeCard(
                        item,
                        brandDarkBlue,
                        brandOrange,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color brandDarkBlue) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: brandDarkBlue,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.analytics_outlined, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Text(
                "Company Working Days: ",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: _workingDaysController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _totalCompanyWorkingDays = parsed;
                        _recalculateReport();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(
    EmployeeMonthlyReport item,
    Color brandDarkBlue,
    Color brandOrange,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Net Salary: \$${item.netSalary.toStringAsFixed(2)}",
          style: TextStyle(color: brandDarkBlue, fontWeight: FontWeight.bold),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.daysPresent.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: brandOrange,
              ),
            ),
            const Text("Days", style: TextStyle(fontSize: 10)),
          ],
        ),
        children: [
          ListTile(
            title: const Text("Attendance"),
            trailing: Text("${item.attendanceRatio.toStringAsFixed(0)}%"),
          ),
          ListTile(
            title: const Text("Total Hours"),
            trailing: Text(item.totalHours.toStringAsFixed(1)),
          ),
          ListTile(
            title: const Text("Overtime"),
            trailing: Text("${item.overtimeHours.toStringAsFixed(1)} Hrs"),
          ),
          ListTile(
            title: const Text("Late Days"),
            trailing: Text(
              item.lateDays.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

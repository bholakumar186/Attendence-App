import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/supabase_service.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> {
  final SupabaseService _supa = SupabaseService();
  List<dynamic> _records = [];
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  final TextEditingController _employeeIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await _supa.fetchAttendanceByDateRange(
      from: _from,
      to: _to,
      employeeId: _employeeIdCtrl.text.trim().isEmpty ? null : _employeeIdCtrl.text.trim(),
    );
    setState(() {
      _records = res;
      _loading = false;
    });
  }

  // --- ANDROID XML EXPORT LOGIC ---

  Future<void> _exportAndShareXml() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available to export")),
      );
      return;
    }

    try {
      // 1. Generate XML String
      final builder = xml.XmlBuilder();
      builder.processing('xml', 'version="1.0" encoding="UTF-8"');
      builder.element('AttendanceReport', nest: () {
        builder.element('GeneratedAt', nest: DateTime.now().toIso8601String());
        builder.element('Records', nest: () {
          for (var r in _records) {
            builder.element('Record', nest: () {
              builder.element('EmployeeID', nest: r['employee_id']);
              builder.element('FullName', nest: r['employees']?['full_name'] ?? 'Unknown');
              builder.element('Date', nest: r['date']);
              builder.element('InTime', nest: r['in_time'] ?? '');
              builder.element('OutTime', nest: r['out_time'] ?? '');
              builder.element('IsLate', nest: r['late'].toString());
              builder.element('TotalWorkSeconds', nest: r['total_work_seconds'] ?? 0);
            });
          }
        });
      });

      final xmlString = builder.buildDocument().toXmlString(pretty: true);

      // 2. Save to temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = "Attendance_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xml";
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(xmlString);

      // 3. Open Android Share Sheet
      // This allows the user to "Save to Device", "Email", or "WhatsApp"
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Attendance Report XML',
        text: 'Attached is the generated attendance report.',
      );

    } catch (e) {
      debugPrint("Export Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UI FORMATTING ---

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return "--:--";
    int s = seconds is int ? seconds : int.parse(seconds.toString());
    final duration = Duration(seconds: s);
    return "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Attendance Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _exportAndShareXml, 
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share XML',
          ),
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          _buildQuickStats(),
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _records.length,
                        itemBuilder: (context, index) => _buildAttendanceCard(_records[index]),
                      ),
          ),
        ],
      ),
    );
  }

  // --- REUSED UI HELPER WIDGETS ---

  Widget _buildQuickStats() {
    int lateCount = _records.where((r) => r['late'] == true).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 70,
      child: Row(
        children: [
          _statTile("Records", _records.length.toString(), Colors.blue),
          const SizedBox(width: 12),
          _statTile("Late Entries", lateCount.toString(), Colors.redAccent),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

 Widget _buildFilterBar() {
  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      children: [
        Expanded(
          child: SearchBar(
            controller: _employeeIdCtrl,
            hintText: "Search ID...",
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(Colors.white),
            onSubmitted: (_) => _fetch(),
            leading: const Icon(Icons.search, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // From Date Chip
        ActionChip(
          label: Text("From: ${DateFormat('MMM d').format(_from)}"),
          onPressed: () => _pickDate(true),
          avatar: const Icon(Icons.calendar_today, size: 14),
        ),
        const SizedBox(width: 4),
        // To Date Chip (The missing piece!)
        ActionChip(
          label: Text("To: ${DateFormat('MMM d').format(_to)}"),
          onPressed: () => _pickDate(false), // Passes false to update _to
          avatar: const Icon(Icons.calendar_today, size: 14),
        ),
      ],
    ),
  );
}
  Widget _buildAttendanceCard(Map<String, dynamic> r) {
    bool isLate = r['late'] ?? false;
    String fullName = r['employees']?['full_name'] ?? 'Unknown Employee';
    
    String inTime = r['in_time'] != null 
        ? DateFormat.jm().format(DateTime.parse(r['in_time'])) 
        : "--";
    String outTime = r['out_time'] != null 
        ? DateFormat.jm().format(DateTime.parse(r['out_time'])) 
        : "Active";
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text("${r['employee_id']} • ${DateFormat('EEE, MMM d').format(DateTime.parse(r['date']))}", 
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (isLate) _buildLateBadge(),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _timeInfo("IN", inTime, Icons.login_rounded, Colors.green),
                _timeInfo("OUT", outTime, Icons.logout_rounded, Colors.orange),
                _timeInfo("TOTAL", _formatDuration(r['total_work_seconds']), Icons.timer_outlined, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: const Text("LATE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _timeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No attendance history found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
Future<void> _pickDate(bool isFrom) async {
  final picked = await showDatePicker(
    context: context,
    // Set initial date to current value
    initialDate: isFrom ? _from : _to,
    // If picking 'To', don't allow dates before 'From'
    firstDate: isFrom 
        ? DateTime.now().subtract(const Duration(days: 365)) 
        : _from, 
    lastDate: DateTime.now(),
  );

  if (picked != null) {
    setState(() {
      if (isFrom) {
        _from = picked;
        // Optional: If 'From' is now after 'To', reset 'To' to 'From'
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
      }
    });
    _fetch();
  }
}
}
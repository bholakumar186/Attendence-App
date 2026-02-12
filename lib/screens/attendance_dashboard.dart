import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

// Ensure these paths match your project structure exactly
import 'camera_screen.dart';
// import 'admin/create_employee_screen.dart';
// import 'admin/attendance_list_screen.dart';
import '../services/supabase_service.dart';
import 'auth/login_screen.dart';

class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  Map<String, dynamic>? _profile;
  int _presentDays = 0;
  Map<String, dynamic>? _today;
  List<dynamic> _recentLogs = [];
  bool _loading = true;

  // Transgulf Brand Identity Colors
  static const Color brandDarkBlue = Color(0xFF002D5B);
  static const Color brandOrange = Color(0xFFF05A28);
  static const Color bgSurface = Color(0xFFF8FAFC);

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController(); // New Controller
    final formKey = GlobalKey<FormState>(); // For validation

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Ensures a clean background
        title: Text(
          'Update Password',
          style: GoogleFonts.poppins(
            color: brandDarkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- New Password Field ---
              TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(
                  color: brandDarkBlue,
                ), // Explicit text color
                decoration: const InputDecoration(
                  labelText: "New Password",
                  labelStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: brandOrange),
                  ),
                ),
                validator: (val) => (val == null || val.length < 6)
                    ? "Minimum 6 characters"
                    : null,
              ),
              const SizedBox(height: 15),

              // --- Confirm Password Field ---
              TextFormField(
                controller: confirmController,
                obscureText: true,
                style: const TextStyle(
                  color: brandDarkBlue,
                ), // Explicit text color
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  labelStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: brandOrange),
                  ),
                ),
                validator: (val) {
                  if (val != passwordController.text)
                    return "Passwords do not match";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandDarkBlue),
            onPressed: () async {
              // Validate both fields
              if (formKey.currentState!.validate()) {
                await _changePassword(passwordController.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(String newPass) async {
    try {
      // Note: Ensure updatePassword exists in your AuthService first!
      await AuthService().updatePassword(newPass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDateTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Time Unknown';
    try {
      // Converts the string to a local DateTime object
      DateTime dateTime = DateTime.parse(timeStr).toLocal();

      // Formats to: "Feb 10, 10:30 AM"
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final supa = SupabaseService();
    try {
      final profile = await supa.getProfile(user.id);
      final employeeId = profile?['employee_id'] ?? user.id;
      final presentCount = await supa.getPresentDaysCount(employeeId);
      final logs = await supa.fetchAttendanceRecords(employeeId);
      final today = await supa.fetchTodayAttendance(employeeId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _presentDays = presentCount;
          _recentLogs = logs;
          _today = today;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandDarkBlue,
        title: Text(
          'TRANSGULF PORTAL',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        actions: [
          // --- ADD THIS PORTION ---
          IconButton(
            icon: const Icon(
              Icons.vpn_key_rounded,
              color: Colors.white70,
              size: 18,
            ),
            onPressed: _showPasswordDialog,
            tooltip: 'Change Password',
          ),
          // ------------------------
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: brandOrange))
          : Column(
              children: [
                _buildProfileHeader(),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        _buildStatGrid(),
                        const SizedBox(height: 25),
                        Text(
                          "RECENT LOGS",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Expanded(child: _buildRecentList()),
                        _buildPunchButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      color: brandDarkBlue,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: brandOrange,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              backgroundImage:
                  (_profile != null && _profile!['reference_photo_url'] != null)
                  ? NetworkImage(_profile!['reference_photo_url'])
                  : null,
              child: (_profile?['reference_photo_url'] == null)
                  ? const Icon(Icons.person, color: brandDarkBlue)
                  : null,
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile?['full_name'] ?? 'Transgulf Employee',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "ID: ${_profile?['employee_id'] ?? 'N/A'}",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
      children: [
        // FIX: Replaced undefined calendar_check_rounded with event_available_rounded
        _statTile(
          "Days Present In this Month",
          _presentDays.toString(),
          Icons.event_available_rounded,
          brandDarkBlue,
        ),
        const SizedBox(width: 15),
        _statTile("Efficiency", "98%", Icons.bolt, brandOrange),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: brandDarkBlue,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    if (_recentLogs.isEmpty) {
      return Center(
        child: Text(
          "No records for this month",
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentLogs.length,
      itemBuilder: (context, index) {
        final row = _recentLogs[index];

        // Determine if we are looking at an IN or OUT action
        final bool hasOutTime = row['out_time'] != null;
        final String displayStatus = hasOutTime ? 'OUT' : 'IN';

        // Get the timestamp string based on status
        final String? rawTimestamp = hasOutTime
            ? row['out_time']
            : row['in_time'];

        // Format the string using our helper
        final String formattedTime = _formatDateTime(rawTimestamp);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: !hasOutTime
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  !hasOutTime ? Icons.login_rounded : Icons.logout_rounded,
                  color: !hasOutTime ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Punch $displayStatus",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: brandDarkBlue,
                    ),
                  ),
                  Text(
                    formattedTime, // Displayed as: Feb 10, 10:30 AM
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPunchButton(BuildContext context) {
    // Decide label and enabled state based on today's attendance and time windows
    final now = DateTime.now();
    DateTime _todayAt(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    final inStart = _todayAt(9, 45);
    final inEnd = _todayAt(20, 20);
    final outStart = _todayAt(10, 00);
    final outEnd = _todayAt(23, 59);
    bool isWithin(DateTime start, DateTime end) =>
        now.isAtSameMomentAs(start) ||
        now.isAtSameMomentAs(end) ||
        (now.isAfter(start) && now.isBefore(end));

    String label = "VERIFY & PUNCH";
    bool enabled = true;
    if (_today == null || _today!['in_time'] == null) {
      label = "VERIFY & PUNCH IN";
      enabled = isWithin(inStart, inEnd);
    } else if (_today!['out_time'] == null) {
      label = "VERIFY & PUNCH OUT";
      enabled = isWithin(outStart, outEnd);
    } else {
      label = "ATTENDANCE COMPLETED";
      enabled = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            // FIX: replaced deprecated withOpacity with .withValues
            BoxShadow(
              color: brandOrange.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: enabled
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ).then((_) => _loadData());
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: brandOrange,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure these paths match your project structure exactly
import 'camera_screen.dart';
import 'admin/create_employee_screen.dart';
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
  List<dynamic> _recentLogs = [];
  bool _loading = true;

  // Transgulf Brand Identity Colors
  static const Color brandDarkBlue = Color(0xFF002D5B);
  static const Color brandOrange = Color(0xFFF05A28);
  static const Color bgSurface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadData();
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

      if (mounted) {
        setState(() {
          _profile = profile;
          _presentDays = presentCount;
          _recentLogs = logs;
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
          if (_profile != null &&
              (_profile!['role'] == 'admin' ||
                  _profile!['role'] == 'superadmin'))
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              tooltip: 'Create Employee',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateEmployeeScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // FIX: Guard BuildContext across async gap
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
                  (_profile != null && _profile!['avatar_url'] != null)
                  ? NetworkImage(_profile!['avatar_url'])
                  : null,
              child: (_profile?['avatar_url'] == null)
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
          "Days Present",
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
        final bool isEntry = row['status'] == 'IN';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // FIX: replaced deprecated withOpacity with .withValues
                  color: isEntry
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEntry ? Icons.login_rounded : Icons.logout_rounded,
                  color: isEntry ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Punch ${row['status']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    row['created_at'] ?? 'Time Unknown',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPunchButton(BuildContext context) {
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
          onPressed: () {
            // FIX: Class name CameraScreen used here.
            // Ensure camera_screen.dart defines "class CameraScreen".
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          },
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
            children: const [
              Icon(Icons.camera_alt_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "VERIFY & PUNCH IN",
                style: TextStyle(
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

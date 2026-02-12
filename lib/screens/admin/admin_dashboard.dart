import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Ensure these imports match your project structure
import 'create_employee_screen.dart';
import 'attendance_list_screen.dart';
import '../auth/login_screen.dart';
import '../../services/supabase_service.dart';
import './all_employees_screen.dart';
import './monthly_report_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _adminProfile;
  // INITIALIZE with empty list to prevent "isEmpty" null errors
  List<Map<String, dynamic>> _todayAttendance = [];
  bool _loading = true;
  bool _loadingAttendance = true;

  static const Color brandDarkBlue = Color(0xFF002D5B);
  static const Color brandOrange = Color(0xFFF05A28);
  static const Color bgSurface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAdminData();
    await _fetchTodayAttendance();
  }

  Future<void> _loadAdminData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final supa = SupabaseService();
      final profile = await supa.getProfile(user.id);
      if (mounted) {
        setState(() {
          _adminProfile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading admin profile: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTodayAttendance() async {
    try {
      if (mounted) setState(() => _loadingAttendance = true);

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await Supabase.instance.client
          .from('attendance')
          .select('*, employees(full_name, employee_id)')
          .eq('date', today)
          .order('in_time', ascending: false);

      if (mounted) {
        setState(() {
          // Explicitly cast and handle potential null response
          _todayAttendance = List<Map<String, dynamic>>.from(response ?? []);
          _loadingAttendance = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
      if (mounted) {
        setState(() {
          _todayAttendance = []; // Set to empty list on error
          _loadingAttendance = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandDarkBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandDarkBlue,
        title: Text(
          'ADMIN PANEL',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchTodayAttendance,
          ),
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
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 30),
                          _buildSectionTitle("Today's Activity"),
                          const SizedBox(height: 15),
                          _buildLiveAttendanceList(), // The widget that was crashing
                          const SizedBox(height: 30),
                          _buildSectionTitle("Management"),
                          const SizedBox(height: 15),
                          _buildAdminCard(
                            context,
                            title: "Create Employee",
                            subtitle: "Register new staff members",
                            icon: Icons.person_add_alt_1,
                            color: brandDarkBlue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateEmployeeScreen(),
                              ),
                            ).then((_) => _fetchTodayAttendance()),
                          ),
                          _buildAdminCard(
                            context,
                            title: "All Employees",
                            subtitle: "View and manage staff list",
                            icon: Icons.people_alt_rounded,
                            color: Colors.blueGrey, // Distinct color
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllEmployeesScreen(),
                              ),
                            ),
                          ),
                          _buildAdminCard(
                            context,
                            title: "Monthly Reports",
                            subtitle: "Days present per employee/month",
                            icon: Icons.calendar_view_month_rounded,
                            color: Colors.teal, // You can choose any color
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MonthlyReportScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAdminCard(
                            context,
                            title: "Attendance Logs",
                            subtitle: "Review historical records",
                            icon: Icons.list_alt_rounded,
                            color: brandOrange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AttendanceListScreen(),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: brandDarkBlue,
      ),
    );
  }

  Widget _buildLiveAttendanceList() {
    if (_loadingAttendance) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange),
        ),
      );
    }

    if (_todayAttendance.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todayAttendance.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = _todayAttendance[index];

        // 1. FIX: Changed 'profiles' to 'employees' to match your JSON/Query
        final employee = record['employees'] as Map<String, dynamic>?;
        final String name = employee?['full_name'] ?? 'Unknown Employee';
        final String empId = employee?['employee_id'] ?? 'N/A';

        // 2. FIX: Changed 'check_out' to 'out_time' to match your JSON
        final bool isCurrentlyIn = record['out_time'] == null;

        // 3. FIX: Changed 'check_in' to 'in_time' to match your JSON
        // Also formatting the ISO string to a readable time
        String formatTime(String? isoString) {
          if (isoString == null) return '--';
          try {
            DateTime dt = DateTime.parse(isoString).toLocal();
            return DateFormat('hh:mm a').format(dt);
          } catch (e) {
            return isoString;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isCurrentlyIn ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: brandDarkBlue,
                      ),
                    ),
                    // Using formatTime to show "05:03 AM" instead of long ISO strings
                    Text(
                      "ID: $empId • In: ${formatTime(record['in_time'])}",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isCurrentlyIn ? "IN" : "OUT",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isCurrentlyIn ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: Colors.grey[300],
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            "No records for today yet.",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
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
          CircleAvatar(
            radius: 25,
            backgroundColor: brandOrange,
            child: const Icon(Icons.admin_panel_settings, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _adminProfile?['full_name'] ?? 'Admin',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Management Portal",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: brandDarkBlue,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import './EmployeeEditScreen.dart';

class AllEmployeesScreen extends StatefulWidget {
  const AllEmployeesScreen({super.key});

  @override
  State<AllEmployeesScreen> createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _fetchAllEmployees();
  }

  Future<void> _fetchAllEmployees() async {
    try {
      final response = await Supabase.instance.client
          .from('employees')
          .select()
          .order('full_name', ascending: true);

      setState(() {
        _employees = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "All Employees",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF002D5B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
          ? const Center(child: Text("No employees found."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(emp['full_name'][0].toUpperCase()),
                    ),
                    title: Text(
                      emp['full_name'],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text("ID: ${emp['employee_id']}"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // Navigate and wait for result to refresh the list if data changed
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeeEditScreen(employee: emp),
                        ),
                      );
                      _fetchAllEmployees(); // Refresh list after returning
                    },
                  ),
                );
              },
            ),
    );
  }
}

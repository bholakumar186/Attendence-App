import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';

class EmployeeEditScreen extends StatefulWidget {
  final Map<String, dynamic> employee;

  const EmployeeEditScreen({super.key, required this.employee});

  @override
  State<EmployeeEditScreen> createState() => _EmployeeEditScreenState();
}

class _EmployeeEditScreenState extends State<EmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _employeeIdController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _joiningDateController;

  // Image Picker variables
  XFile? _pickedImage;
  String? _currentPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  // Form state variables
  late String _selectedRole;
  late bool _isActive;
  DateTime? _selectedDate;
  bool _isSaving = false;

  final List<String> _roles = ['employee', 'admin', 'manager'];

  @override
  void initState() {
    super.initState();
    final data = widget.employee;

    // Initialize text controllers
    _nameController = TextEditingController(text: data['full_name']);
    _employeeIdController = TextEditingController(text: data['employee_id']);
    _emailController = TextEditingController(text: data['email'] ?? '');
    _phoneController = TextEditingController(text: data['phone'] ?? '');

    // Handle Image
    _currentPhotoUrl = data['reference_photo_url'];

    // Handle Date
    if (data['date_of_joining'] != null) {
      _selectedDate = DateTime.parse(data['date_of_joining']);
      _joiningDateController = TextEditingController(
          text: DateFormat('yyyy-MM-dd').format(_selectedDate!));
    } else {
      _joiningDateController = TextEditingController();
    }

    _selectedRole = data['role'] ?? 'employee';
    _isActive = data['active'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _joiningDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _joiningDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? finalPhotoUrl = _currentPhotoUrl;

      // 1. Upload new photo if picked
      if (_pickedImage != null) {
        finalPhotoUrl = await SupabaseService().updateEmployeePhoto(
          widget.employee['id'],
          _pickedImage!,
        );
      }

      // 2. Update Database (Fixed _idController to _employeeIdController)
      await Supabase.instance.client.from('employees').update({
        'full_name': _nameController.text.trim(),
        'employee_id': _employeeIdController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'active': _isActive,
        'reference_photo_url': finalPhotoUrl,
        'updated_at': DateTime.now().toIso8601String(),
        'date_of_joining': _selectedDate?.toIso8601String(),
      }).eq('id', widget.employee['id']);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Profile Updated!")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: _pickedImage != null
                ? FileImage(File(_pickedImage!.path))
                : (_currentPhotoUrl != null
                        ? NetworkImage(_currentPhotoUrl!)
                        : null)
                    as ImageProvider?,
            child: (_pickedImage == null && _currentPhotoUrl == null)
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Color(0xFFF05A28), shape: BoxShape.circle),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Employee",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF002D5B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoSection(), // Added the photo section here
              const SizedBox(height: 32),
              _buildTextField("Full Name", _nameController, Icons.person),
              const SizedBox(height: 16),
              _buildTextField("Employee ID", _employeeIdController, Icons.badge),
              const SizedBox(height: 16),
              _buildTextField("Email Address", _emailController, Icons.email,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField("Phone Number", _phoneController, Icons.phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              // Date of Joining
              TextFormField(
                controller: _joiningDateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  labelText: "Date of Joining",
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Role Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedRole, // Changed 'value' to 'initialValue'
                decoration: InputDecoration(
                  labelText: "Role",
                  prefixIcon: const Icon(Icons.security),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _roles
                    .map((role) => DropdownMenuItem(
                        value: role, child: Text(role.toUpperCase())))
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: 16),

              // Active Status Switch
              SwitchListTile(
                title: Text("Active Status", style: GoogleFonts.poppins()),
                subtitle: Text(_isActive ? "Currently Active" : "Inactive"),
                value: _isActive,
                activeThumbColor: const Color(0xFFF05A28), // Changed activeColor
                onChanged: (val) => setState(() => _isActive = val),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("SAVE CHANGES",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (label == "Full Name" || label == "Employee ID") {
          return (value == null || value.isEmpty) ? "Required field" : null;
        }
        return null;
      },
    );
  }
}
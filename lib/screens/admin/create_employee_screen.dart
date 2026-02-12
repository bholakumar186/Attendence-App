import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart'; 

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController(text: 'Employee');
  final _adminUrlCtrl = TextEditingController();
  final _adminKeyCtrl = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  // State Variables - Initialized to prevent 'Null' subtype errors
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureAdminKey = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _adminUrlCtrl.dispose();
    _adminKeyCtrl.dispose();
    super.dispose();
  }

  // Helper for consistent UI styling
  InputDecoration _buildDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final supa = SupabaseService();
      final res = await supa.createEmployeeViaAdmin(
        imageFile: _selectedImage,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        role: _roleCtrl.text.trim().toLowerCase(),
        adminApiUrl: _adminUrlCtrl.text.trim(),
        adminApiKey: _adminKeyCtrl.text.trim(),
      );

      if (mounted) setState(() => _loading = false);

      if (res['success'] == true) {
        _showSnackBar('Staff account created successfully', Colors.green);
        Navigator.of(context).pop();
      } else {
        _showSnackBar(res['message'] ?? 'Creation failed', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showSnackBar('An unexpected error occurred', Colors.redAccent);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Onboard New Staff',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildSectionHeader("Personal Details"),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : null,
                  child: _selectedImage == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 30,
                          color: Colors.blueGrey,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: _buildDecoration('Full Name', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter full name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: _buildDecoration('Work Email', Icons.alternate_email),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Invalid email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword, // Fixed: uses initialized bool
              decoration: _buildDecoration(
                'Temporary Password',
                Icons.lock_open_outlined,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  (v != null && v.length < 6) ? 'Min 6 characters' : null,
            ),

            const SizedBox(height: 32),
            _buildSectionHeader("Employment Info"),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    decoration: _buildDecoration('Phone', Icons.phone_android),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _roleCtrl,
                    decoration: _buildDecoration(
                      'Designation',
                      Icons.work_outline,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSectionHeader("Company System Authorization"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _adminUrlCtrl,
                    decoration: _buildDecoration(
                      'Company Gateway URL',
                      Icons.lan_outlined,
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Gateway required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adminKeyCtrl,
                    obscureText:
                        _obscureAdminKey, // Fixed: uses initialized bool
                    decoration: _buildDecoration(
                      'System Service Key',
                      Icons.vpn_key_outlined,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureAdminKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureAdminKey = !_obscureAdminKey,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Service key required'
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Registration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey.shade800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

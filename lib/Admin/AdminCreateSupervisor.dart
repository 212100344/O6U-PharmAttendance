import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminCreateSupervisor extends StatefulWidget {
  const AdminCreateSupervisor({Key? key}) : super(key: key);

  @override
  State<AdminCreateSupervisor> createState() => _AdminCreateSupervisorState();
}

class _AdminCreateSupervisorState extends State<AdminCreateSupervisor> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController trainingCenterController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();
  final TextEditingController supervisorIdController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  /// Function to create a supervisor by bypassing Supabase Auth providers.
  Future<void> _createSupervisor() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final trainingCenterName = trainingCenterController.text.trim();
      final nationalId = nationalIdController.text.trim();
      final supervisorIdInput = supervisorIdController.text.trim();

      if (email.isEmpty ||
          password.isEmpty ||
          firstName.isEmpty ||
          lastName.isEmpty ||
          trainingCenterName.isEmpty ||
          nationalId.isEmpty ||
          supervisorIdInput.isEmpty) {
        throw Exception("❌ All fields are required!");
      }

      // Step 1: Check if the training center already exists.
      final existingCenterResponse = await Supabase.instance.client
          .from('training_centers')
          .select('id')
          .eq('name', trainingCenterName)
          .maybeSingle();

      String trainingCenterId;
      if (existingCenterResponse != null) {
        trainingCenterId = existingCenterResponse['id'];
      } else {
        trainingCenterId = const Uuid().v4();
        // Insert the new training center.
        await Supabase.instance.client
            .from('training_centers')
            .insert({
          'id': trainingCenterId,
          'name': trainingCenterName,
        }).select();
      }

      // Step 2: Bypass Auth creation.
      // Check if a profile with the given email exists.
      final existingProfile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      String userId;
      if (existingProfile != null && existingProfile['id'] != null) {
        userId = existingProfile['id'];
      } else {
        userId = const Uuid().v4();
      }

      // Step 3: Upsert supervisor details into the `profiles` table.
      // Include the provided password to satisfy the not-null constraint.
      final profileData = {
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'national_id': nationalId,
        'student_id': supervisorIdInput, // used here as Supervisor ID
        'role': 'supervisor',
        'status': 'active',
        'password': password,
      };

      await Supabase.instance.client
          .from('profiles')
          .upsert(profileData)
          .select();

      // Step 4: Upsert the record in the `supervisors` table.
      final supervisorData = {
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'training_center_id': trainingCenterId,
      };

      await Supabase.instance.client
          .from('supervisors')
          .upsert(supervisorData)
          .select();

      // Success: Clear all the fields.
      setState(() {
        emailController.clear();
        passwordController.clear();
        firstNameController.clear();
        lastNameController.clear();
        trainingCenterController.clear();
        nationalIdController.clear();
        supervisorIdController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Supervisor created successfully!")),
      );
    } catch (e) {
      setState(() {
        errorMessage = "❌ Error: $e";
      });
      print("❌ Error creating supervisor: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Builds a custom text field with consistent styling.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: GoogleFonts.inter(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// UI for creating a supervisor.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "👨‍🏫 Create Supervisor",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 8,
        shadowColor: Colors.deepPurple.withOpacity(0.4),
      ),
      backgroundColor: const Color(0xFFE9ECEF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(
              controller: firstNameController,
              label: "First Name",
            ),
            _buildTextField(
              controller: lastNameController,
              label: "Last Name",
            ),
            _buildTextField(
              controller: emailController,
              label: "Email",
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              controller: passwordController,
              label: "Password",
              obscureText: true,
            ),
            _buildTextField(
              controller: trainingCenterController,
              label: "Training Center Name",
            ),
            _buildTextField(
              controller: nationalIdController,
              label: "National ID",
              keyboardType: TextInputType.number,
            ),
            _buildTextField(
              controller: supervisorIdController,
              label: "Supervisor ID",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  errorMessage!,
                  style: GoogleFonts.inter(color: Colors.red),
                ),
              ),
            isLoading
                ? const CircularProgressIndicator(
              color: Colors.deepPurple,
            )
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createSupervisor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("✅ Create Supervisor"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

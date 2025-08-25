import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'CheckAttendance.dart';
import 'GenerateQRCode.dart';
import 'SupervisorStudentReportsScreen.dart';
import 'SupervisorViewRounds.dart';
import '../AdminStudent.dart'; // Add this import to go back to main page

/// -------------------- TraineeSupervisorHome --------------------
class TraineeSupervisorHome extends StatefulWidget {
  final String email;

  const TraineeSupervisorHome({Key? key, required this.email})
      : super(key: key);

  @override
  State<TraineeSupervisorHome> createState() => _TraineeSupervisorHomeState();
}

class _TraineeSupervisorHomeState extends State<TraineeSupervisorHome> {
  String firstName = '';
  String lastName = '';
  String nationalId = '';
  String location = 'Fetching location...';
  bool isLoading = true;
  bool locationFetchFailed = false;
  String role = 'Loading...';
  String status = 'Loading...';
  String trainingCenterName = 'Loading...';
  String? supervisorId; // Will hold the supervisor's ID
  String trainingCenterId = ''; // Store training center id

  @override
  void initState() {
    super.initState();
    _fetchSupervisorDetails();
    _getLocation();
  }

  Future<void> _fetchSupervisorDetails() async {
    try {
      final normalizedEmail = widget.email.trim().toLowerCase();

      // Fetch profile details (including the supervisor's id)
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, first_name, last_name, national_id, role, status')
          .ilike('email', normalizedEmail)
          .single();

      // Fetch supervisor details (from supervisors table) for training center id
      final supervisorResponse = await Supabase.instance.client
          .from('supervisors')
          .select('training_center_id, email')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      trainingCenterId = supervisorResponse?['training_center_id'] ?? '';

      // Fetch training center name if available
      if (trainingCenterId.isNotEmpty) {
        final trainingCenterResponse = await Supabase.instance.client
            .from('training_centers')
            .select('name')
            .eq('id', trainingCenterId)
            .maybeSingle();
        trainingCenterName = trainingCenterResponse?['name'] ?? 'Unknown';
      }

      setState(() {
        firstName = profileResponse['first_name'] ?? '';
        lastName = profileResponse['last_name'] ?? '';
        nationalId = profileResponse['national_id'] ?? '';
        role = profileResponse['role'] ?? '';
        status = profileResponse['status'] ?? '';
        supervisorId = profileResponse['id']; // Use profile id as supervisor id
      });
    } catch (e) {
      print('Error fetching supervisor details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      location = 'Fetching location...';
      locationFetchFailed = false;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _handleLocationError('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _handleLocationError('Location permissions are permanently denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        setState(() {
          location =
          'City: ${place.locality}, Country: ${place.country}\n'
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
        });
      } else {
        _handleLocationError('Unable to determine location');
      }
    } catch (e) {
      _handleLocationError('Error fetching location: ${e.toString()}');
    }
  }

  void _handleLocationError(String message) {
    setState(() {
      location = message;
      locationFetchFailed = true;
    });
  }

  void _showSupervisorInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Supervisor Information",
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow("First Name:", firstName),
              _buildInfoRow("Last Name:", lastName),
              _buildInfoRow("National ID:", nationalId),
              _buildInfoRow("Role:", role),
              _buildInfoRow("Status:", status),
              _buildInfoRow("Training Center:", trainingCenterName),
              const SizedBox(height: 16),
              _buildInfoRow("Location:", location),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.inter())),
        ],
      ),
    );
  }

  /// Service card builder (similar to StudentHome)
  Widget _buildServiceCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.deepPurple[800],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  locationFetchFailed
                      ? Icons.error_outline_rounded
                      : Icons.location_on_rounded,
                  color: locationFetchFailed ? Colors.red : Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  locationFetchFailed ? 'Location Error' : 'Current Location',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: locationFetchFailed ? Colors.red : Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              location,
              style: GoogleFonts.inter(
                color: locationFetchFailed ? Colors.red : Colors.grey[600],
              ),
            ),
            if (locationFetchFailed)
              TextButton(
                onPressed: _getLocation,
                child: Text(
                  'Retry Location',
                  style: GoogleFonts.inter(color: Colors.deepPurple),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToGenerateQRCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateQRCode(email: widget.email),
      ),
    );
  }

  void _navigateToCheckAttendance() {
    if (supervisorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckAttendance(supervisorId: supervisorId!),
        ),
      );
    }
  }

  void _navigateToViewRounds() {
    if (supervisorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupervisorViewRounds(supervisorId: supervisorId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Supervisor ID not available", style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Navigate to EvaluateStudentsScreen
  void _navigateToEvaluateStudents() {
    if (supervisorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EvaluateStudentsScreen(supervisorId: supervisorId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Supervisor ID not available", style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ... inside _buildMainContent() in TraineeSupervisorHome.dart
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, $firstName $lastName",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Supervisor Portal",
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildServiceCard(
            icon: Icons.qr_code,
            label: "Generate QR Code",
            onTap: _navigateToGenerateQRCode,
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.list_alt,
            label: "Check Attendance",
            onTap: _navigateToCheckAttendance,
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.calendar_today,
            label: "View Rounds",
            onTap: _navigateToViewRounds,
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.rate_review,
            label: "Evaluate Students",
            onTap: _navigateToEvaluateStudents,
          ),
          const SizedBox(height: 16),
          // New "Student Reports" button:
          _buildServiceCard(
            icon: Icons.report,
            label: "Student Reports",
            onTap: () {
              if (supervisorId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupervisorStudentReportsScreen(
                      supervisorId: supervisorId!,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Supervisor ID not available", style: GoogleFonts.inter()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 32),
          _buildLocationCard(),
        ],
      ),
    );
  }

  // Added Logout function. Identical to StudentHome.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Clear login state
    await prefs.remove('userRole'); // Remove the user role
    await prefs.remove('email');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminStudent()),
              (route) => false); // Remove all previous routes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Supervisor Portal",
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showSupervisorInfo,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout, // Call the logout function
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _buildMainContent(),
    );
  }
}

/// -------------------- EvaluateStudentsScreen --------------------
class EvaluateStudentsScreen extends StatefulWidget {
  final String supervisorId;

  const EvaluateStudentsScreen({Key? key, required this.supervisorId})
      : super(key: key);

  @override
  State<EvaluateStudentsScreen> createState() => _EvaluateStudentsScreenState();
}

class _EvaluateStudentsScreenState extends State<EvaluateStudentsScreen> {
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents();
  }

  Future<void> _fetchEnrolledStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // 1. Fetch the rounds led by the current supervisor.
      final roundsResponse = await Supabase.instance.client
          .from('rounds')
          .select('id')
          .eq('leader_id', widget.supervisorId);

      // Extract the round IDs into a list.
      final List<String> roundIds = roundsResponse
          .map<String>((row) => row['id'] as String)
          .toList();

      // 2. If no rounds are found, handle it gracefully.
      if (roundIds.isEmpty) {
        setState(() {
          students = []; // No students to show.
          isLoading = false;
        });
        return; // Exit early.
      }

      // 3. Fetch students enrolled in those rounds, joining with profiles.
      final studentsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('student_id, profiles!fk_student_rounds_profiles(first_name, last_name, student_id)')
          .filter('round_id', 'in', '(${roundIds.join(',')})') // Updated filter for list of round IDs
          .eq('status', 'in_progress'); // Get active student

      // 4. Remove duplicate student entries (a student might be in multiple rounds).
      final seenStudentIds = <String>{};
      final uniqueStudents = <Map<String, dynamic>>[];

      for (final record in studentsResponse) {
        final studentId = record['student_id'] as String?;
        if (studentId != null && !seenStudentIds.contains(studentId)) {
          seenStudentIds.add(studentId);
          uniqueStudents.add({
            'id': studentId,
            'first_name': record['profiles']['first_name'] ?? 'Unknown',
            'last_name': record['profiles']['last_name'] ?? '',
            'student_id': record['profiles']['student_id'] ?? 'N/A',
          });
        }
      }
      // For debug.
      print("student id is: $studentsResponse");

      setState(() {
        students = uniqueStudents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching students: $e';
      });
    }
  }

  void _navigateToEvaluateStudentDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluateStudentDetailScreen(
          supervisorId: widget.supervisorId,
          student: student,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Evaluate Students",
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : errorMessage.isNotEmpty
          ? Center(child: Text(errorMessage, style: GoogleFonts.inter()))
          : RefreshIndicator(
        onRefresh: _fetchEnrolledStudents,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final fullName = "${student['first_name']} ${student['last_name']}";
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Text(
                  fullName.substring(0, 1),
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
              title: Text(fullName, style: GoogleFonts.poppins()),
              subtitle: Text("ID: ${student['student_id']}", style: GoogleFonts.inter()),
              trailing: Icon(Icons.chevron_right, color: Colors.deepPurple[800]),
              onTap: () => _navigateToEvaluateStudentDetail(student),
            );
          },
        ),
      ),
    );
  }
}

/// -------------------- EvaluateStudentDetailScreen --------------------
class EvaluateStudentDetailScreen extends StatefulWidget {
  final String supervisorId;
  final Map<String, dynamic> student;

  const EvaluateStudentDetailScreen({
    Key? key,
    required this.supervisorId,
    required this.student,
  }) : super(key: key);

  @override
  State<EvaluateStudentDetailScreen> createState() =>
      _EvaluateStudentDetailScreenState();
}

class _EvaluateStudentDetailScreenState extends State<EvaluateStudentDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool isSubmitting = false;
  String submitMessage = '';

  Future<void> _submitEvaluation() async {
    setState(() {
      isSubmitting = true;
      submitMessage = '';
    });

    try {
      final insertedData = await Supabase.instance.client
          .from('evaluations')
          .insert({
        'supervisor_id': widget.supervisorId,
        'student_id': widget.student['id'],
        'comments': _commentController.text.trim(),
      })
          .select();

      if (insertedData != null && insertedData.isNotEmpty) {
        setState(() {
          submitMessage = 'Evaluation submitted successfully!';
        });
      } else {
        setState(() {
          submitMessage = 'Error: No data returned from insert.';
        });
      }
    } catch (e) {
      setState(() {
        submitMessage = 'Submission error: $e';
      });
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = "${widget.student['first_name']} ${widget.student['last_name']}";

    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Evaluate $fullName",
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Provide your evaluation and comments below:",
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Enter comments here...",
                hintStyle: GoogleFonts.inter(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            isSubmitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _submitEvaluation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Submit Evaluation",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (submitMessage.isNotEmpty)
              Text(
                submitMessage,
                style: GoogleFonts.inter(
                  color: submitMessage.contains('success') ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

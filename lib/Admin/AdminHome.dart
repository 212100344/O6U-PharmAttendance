
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens you referenced (keep these as needed):
import 'ApproveSignUps.dart';
import 'AdminCreateSupervisor.dart';
import 'AdminManageRounds.dart';
import 'AdminManageSupervisors.dart';
import 'ManageStudentsScreen.dart';
import 'Evaluation/ShowEvaluation.dart';
import '../AdminStudent.dart'; // Import to navigate to AdminStudent


class AdminHome extends StatefulWidget {
  final String email; // Passed from the sign-in process (from profiles)

  const AdminHome({super.key, required this.email});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // ----------------------------
  // State variables
  // ----------------------------
  String email = '';
  String firstName = '';
  String lastName = '';
  String nationalId = '';
  String studentId = '';
  String role = '';
  String status = '';
  String location = 'Fetching location...';
  bool isLoading = true;
  bool locationFetchFailed = false;

  // ----------------------------
  // initState and data fetching
  // ----------------------------
  @override
  void initState() {
    super.initState();
    _fetchAdminDetails();
    _getLocation();
  }

  Future<void> _fetchAdminDetails() async {
    try {
      // Use the email passed to this widget and normalize it.
      final normalizedEmail = widget.email.trim().toLowerCase();
      print("Using admin email: $normalizedEmail");

      // Query the profiles table for admin details.
      final response = await Supabase.instance.client
          .from('profiles')
          .select(
        'email, first_name, last_name, national_id, student_id, role, status',
      )
          .ilike('email', normalizedEmail)
          .single();

      print("Fetched admin details: $response");

      setState(() {
        email = response['email'] ?? '';
        firstName = response['first_name'] ?? 'Admin';
        lastName = response['last_name'] ?? '';
        nationalId = response['national_id'] ?? '';
        studentId = response['student_id'] ?? '';
        role = response['role'] ?? '';
        status = response['status'] ?? '';
      });
    } catch (e) {
      print('Error fetching admin details: $e');
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
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        setState(() {
          location =
          'City: ${place.locality}, Country: ${place.country}\n'
              'Lat: ${position.latitude.toStringAsFixed(4)}, '
              'Lon: ${position.longitude.toStringAsFixed(4)}';
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

  // ----------------------------
  // Build method with new UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Enhanced AppBar with gradient
      appBar: AppBar(
        title: Text(
          "Admin Portal",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
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
            onPressed: _showAdminInfo,
          ),
          //Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Padding(
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
              "Admin Dashboard",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Approve Sign Ups
            _buildServiceCard(
              icon: Icons.person_add_rounded,
              label: "Approve Student Sign Ups",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApproveSignUps(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Create Supervisor
            _buildServiceCard(
              icon: Icons.supervisor_account_rounded,
              label: "Create Supervisor",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminCreateSupervisor(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Manage Supervisors
            _buildServiceCard(
              icon: Icons.manage_accounts_rounded,
              label: "Manage Supervisors",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminManageSupervisors(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Manage Rounds
            _buildServiceCard(
              icon: Icons.date_range_rounded,
              label: "Manage Rounds",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminManageRounds(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Manage Students
            _buildServiceCard(
              icon: Icons.school_rounded,
              label: "Manage Students",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageStudentsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Show Evaluations
            _buildServiceCard(
              icon: Icons.assessment_rounded,
              label: "Show Evaluation",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShowEvaluation(),
                ),
              ),
            ),

            const SizedBox(height: 32),
            _buildLocationCard(),
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // Card builder helpers
  // ----------------------------
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
                    color:
                    locationFetchFailed ? Colors.red : Colors.grey[800],
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
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // Admin info dialog
  // ----------------------------
  void _showAdminInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Admin Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow("Email:", email),
              _buildInfoRow("First Name:", firstName),
              _buildInfoRow("Last Name:", lastName),
              _buildInfoRow("National ID:", nationalId),
              _buildInfoRow("Mobile Phone:", studentId),
              _buildInfoRow("Role:", role),
              _buildInfoRow("Status:", status),
              const SizedBox(height: 16),
              Text(
                "Location:",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              Text(location, style: GoogleFonts.inter()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

   // Added Logout function.
    Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Clear login state
    await prefs.remove('userRole'); // Remove the user role
    await prefs.remove('email'); // Also good to clear the email.

      if(mounted){
      // Navigate to the AdminStudent screen (the initial screen).  Use pushAndRemoveUntil
         Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminStudent()),
            (route) => false); // Remove all previous routes
    }
 }
}
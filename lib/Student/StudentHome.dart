// lib/Student/StudentHome.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendance_sys/utils/notification_service.dart'; // Import
import 'FinalEvaluationScreen.dart';
import 'ScanQRCode.dart';
import 'StudentSelectRound.dart';
import 'ViewAttendanceRecord.dart';
import '../AdminStudent.dart';
import 'package:attendance_sys/Student/TrainingTermsScreen.dart';
import 'package:intl/intl.dart'; // Import intl

// NEW: Import the NotificationListScreen
import 'NotificationListScreen.dart'; // Import the notification list screen

class StudentHome extends StatefulWidget {
  final String email;

  const StudentHome({Key? key, required this.email}) : super(key: key);

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  String firstName = '';
  String lastName = '';
  String studentId = '';
  String nationalId = '';
  String location = 'Fetching location...';
  bool isLoading = true;
  bool locationFetchFailed = false;
  String? _studentUserId;
  String currentRoundSupervisor = "N/A";
  String status = 'Loading...';
  String? activeRoundId; // Add this
  @override
  void initState() {
    super.initState();
    _fetchStudentDetails(initialFetch: true);
    _getLocation();
  }

  Future<void> _fetchStudentDetails({bool initialFetch = false}) async {
    if (!initialFetch) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final normalizedEmail = widget.email.trim().toLowerCase();

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
          'first_name, last_name, student_id, national_id, id, status')
          .ilike('email', normalizedEmail)
          .single();

      if(mounted){
        setState(() {
          firstName = response['first_name'] ?? 'Student';
          lastName = response['last_name'] ?? '';
          studentId = response['student_id'] ?? '';
          nationalId = response['national_id'] ?? '';
          _studentUserId = response['id'];
          status = response['status'] ?? 'inactive';
        });
      }

      await _fetchCurrentRoundSupervisor(response['id']);

      if (!initialFetch && status.toLowerCase() == 'active') {
        await _checkAndShowNotification();
      }
    } catch (e) {
      print('Error fetching student details: $e');
    } finally {
      if(mounted){
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkAndShowNotification() async {
    final hasSent = await notificationService.hasNotificationBeenSent(widget.email);

    if (!hasSent) {
      await notificationService.showNotification(
        widget.email.hashCode,
        "Account Approved",
        "Your O6U Pharmacy account has been approved. You can use it now!",
      );
      await notificationService.saveNotification(
          widget.email,
          "Account Approved",
          "Your O6U Pharmacy account has been approved. You can use it now!"
      );

      await notificationService.setNotificationSentFlag(widget.email);
    }
  }

  Future<void> _fetchCurrentRoundSupervisor(String studentId) async {
    try {
      final activeRoundResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id, rounds!inner(leader_id, name, start_date, end_date, location)') // Select necessary fields
          .eq('student_id', studentId)
          .eq('status', 'in_progress')
          .limit(1)
          .maybeSingle();


      if (activeRoundResponse != null && activeRoundResponse['round_id'] != null) {
        final roundId = activeRoundResponse['round_id'];
        final roundData =  activeRoundResponse['rounds'];

        if (roundData != null && roundData['leader_id'] != null) {
          final leaderId = roundData['leader_id'];

          final supervisorResponse = await Supabase.instance.client
              .from('supervisors')
              .select('first_name, last_name')
              .eq('id', leaderId)
              .single();
          if(mounted){
            setState(() {
              currentRoundSupervisor =
                  "${supervisorResponse['first_name'] ?? ''} ${supervisorResponse['last_name'] ?? ''}"
                      .trim();
              // Also set activeRoundId in the state, if needed elsewhere
              activeRoundId = roundId;
            });

          }
          await _checkAndShowRoundNotification(roundData);
        }
      } else{
        if(mounted){
          setState(() {
            activeRoundId = null; // No active round, added!
          });
        }

      }
    } catch (e) {
      print("Error fetching current round supervisor: $e");
    }
  }

  Future<void> _checkAndShowRoundNotification(Map<String, dynamic> round) async {

    final roundName = round['name'] ?? 'Unknown Round';
    final supervisorName = currentRoundSupervisor;
    final location = round['location'] ?? 'Unknown Location';
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(round['start_date']));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(round['end_date']));

    final notificationKey = 'round_notification_${widget.email}_${round['id']}'; // Use email here, more reliable
    final hasSent = await notificationService.hasNotificationBeenSent(notificationKey);

    if (!hasSent) {
      final notificationTitle = "Enrolled in $roundName";
      final notificationBody =
          "You are enrolled in $roundName, led by $supervisorName.\n"
          "Location: $location\n"
          "Dates: $startDate - $endDate";

      await notificationService.showNotification(
        notificationKey.hashCode, // Unique ID
        notificationTitle,
        notificationBody,
      );

      await notificationService.saveNotification(widget.email,notificationTitle, notificationBody); // Save using email
      await notificationService.setNotificationSentFlag(notificationKey);
    }
  }

  Future<void> _getLocation() async {
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
        _handleLocationError(
            'Location permissions are permanently denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        if (mounted) {
          setState(() {
            location =
            'City: ${place.locality}, Country: ${place.country}\n'
                'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(
                4)}';
          });
        }
      } else {
        _handleLocationError('Unable to determine location');
      }
    } catch (e) {
      _handleLocationError('Error fetching location: ${e.toString()}');
    }
  }

  void _handleLocationError(String message) {
    if(mounted) {
      setState(() {
        location = message;
        locationFetchFailed = true;
      });
    }
  }
  void _showStudentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Student Information",
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("First Name:", firstName),
            _buildInfoRow("Last Name:", lastName),
            _buildInfoRow("Student ID:", studentId),
            _buildInfoRow("National ID:", nationalId),
            _buildInfoRow("Current Round Supervisor:", currentRoundSupervisor),
            _buildInfoRow("Status", status),  // Show the status here
            const SizedBox(height: 16),
            _buildInfoRow("Location:", location),
          ],
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
          Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.inter())),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnabled
                        ? [const Color(0xFF7C4DFF), const Color(0xFF448AFF)]
                        : [Colors.grey, Colors.grey[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: isEnabled ? Colors.white : Colors.grey[300],
                    size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.grey[800] : Colors.grey,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isEnabled ? Colors.deepPurple[800] : Colors.grey,
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
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Clear login state
    await prefs.remove('userRole'); // Remove the user role
    await prefs.remove('email');
    if(mounted){
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminStudent()),
            (route) => false, // Remove all previous routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Student Portal",
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
            onPressed: _showStudentInfo,
          ),
          //Logout
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE9ECEF),
      body: isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.deepPurple))
          : _buildMainContent(),
    );
  }
  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: () =>
          _fetchStudentDetails(
              initialFetch: false), // Pass false on refresh
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
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
              "Student Portal",
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            if (status.toLowerCase() == 'inactive') ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Your account is awaiting admin approval.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            _buildServiceCard(
              icon: Icons.description,
              label: "Review Training Terms",
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrainingTermsScreen(),
                    ),
                  ),
              isEnabled: true,
            ),
            const SizedBox(height: 16),

            _buildServiceCard(
              icon: Icons.qr_code_scanner,
              label: "Scan QR Code",
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ScanQRCode(studentEmail: widget.email),
                    ),
                  ),
              isEnabled:
              status.toLowerCase() == 'active', // Disable if inactive
            ),
            const SizedBox(height: 16),
            _buildServiceCard(
              icon: Icons.list_alt,
              label: "View Attendance Record",
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewAttendanceRecord(
                              studentEmail: widget
                                  .email), //Fixed: push student email, no need for student id,
                      // it used and created with it when it sign in to the application.
                    ),
                  ),
              isEnabled: status.toLowerCase() == 'active',
            ),
            const SizedBox(height: 16),
            _buildServiceCard(
              icon: Icons.calendar_today,
              label: "Select Round",
              onTap: () {
                if (_studentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentSelectRound(studentId: _studentUserId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Student ID not available"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              isEnabled: status.toLowerCase() == 'active',
            ),
            const SizedBox(height: 16),
            _buildServiceCard(
              icon: Icons.assessment,
              label: "Final Evaluation",
              onTap: () {
                if (_studentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FinalEvaluationScreen(studentId: _studentUserId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Student ID not available",
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.red),
                  );
                }
              },
              isEnabled: status.toLowerCase() == 'active',
            ),

            // NEW: Notifications List Button
            const SizedBox(height: 16),
            _buildServiceCard(
              icon: Icons.notifications,
              label: "Show Notifications",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NotificationListScreen(studentId: widget.email),
                  ),
                );
              },
              isEnabled: true, // Always enabled
            ),

            const SizedBox(height: 32),
            _buildLocationCard(),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

class SupervisorStudentReportDetailScreen extends StatefulWidget {
  final String studentId;
  final String roundId; // Add roundId

  const SupervisorStudentReportDetailScreen(
      {Key? key, required this.studentId, required this.roundId}) // Add roundId
      : super(key: key);

  @override
  State<SupervisorStudentReportDetailScreen> createState() =>
      _SupervisorStudentReportDetailScreenState();
}

class _SupervisorStudentReportDetailScreenState
    extends State<SupervisorStudentReportDetailScreen> {
  bool isLoading = true;
  Map<String, dynamic>? studentData;
  int attendancePercentage = 0; //  Rename and keep as an integer
  String? errorMessage;
  bool allDaysExcluded = false; // Store all days excluded

  @override
  void initState() {
    super.initState();
    _fetchStudentReport();
  }

  Future<void> _fetchStudentReport() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // --- Fetch student profile ---  (No changes here)
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, student_id, national_id')
          .eq('id', widget.studentId)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception("Student not found");
      }

      // --- Fetch Round information ---  (Fetch start and end dates)
      final roundResponse = await Supabase.instance.client
          .from('rounds')
          .select('start_date, end_date')
          .eq('id', widget.roundId)  // Use the passed roundId
          .maybeSingle(); // Expecting one or zero rounds.

      if (roundResponse == null) {
        throw Exception("Round not found"); // Handle missing round
      }

      final startDate = DateTime.parse(roundResponse['start_date']);
      final endDate = DateTime.parse(roundResponse['end_date']);
      int expectedDays = endDate.difference(startDate).inDays + 1;

      // --- Excluded Dates Logic ---
      final excludedDatesResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', widget.roundId); // Use widget.roundId

      Set<DateTime> excludedDates = (excludedDatesResponse as List)
          .map((item) => DateTime.parse(item['date']).toLocal())
          .toSet();

      int excludedDaysCount = 0;
      for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
        if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {
          excludedDaysCount++;
        }
      }

      // --- Calculate *actual* expected days ---
      expectedDays -= excludedDaysCount;

      if (expectedDays == 0) {
        allDaysExcluded = true; // set attribute
        expectedDays = 1; // Prevent division by zero
      }
      // --- Fetch Attendance (for the specific round) ---
      final attendanceResponse = await Supabase.instance.client
          .from('attendance')
          .select('scanned_date')
          .eq('round_id', widget.roundId) // Use widget.roundId
          .eq('student_id', widget.studentId);

      final attendedDays = (attendanceResponse as List?)?.length ?? 0;

      // --- Calculate Attendance Percentage ---
      attendancePercentage = expectedDays > 0
          ? ((attendedDays / expectedDays) * 100).round()
          : 0; //I will set it with allDaysExcluded

      // set it with 100
      if(allDaysExcluded){
        attendancePercentage = 100;
      }
      setState(() {
        studentData = {
          ...profileResponse,  // Keep existing data
          'attendancePercentage': attendancePercentage, // Add percentage
          'allDaysExcluded': allDaysExcluded,  // Add
        };
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching report: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String getBirthday(String? nationalId) {
    if (nationalId == null || nationalId.isEmpty) {
      return "Unknown";
    }
    if (nationalId.length >= 7 && nationalId.startsWith("3")) {
      String yearPart = nationalId.substring(1, 3);
      String monthPart = nationalId.substring(3, 5);
      String dayPart = nationalId.substring(5, 7);
      int year = 2000 + int.parse(yearPart);
      int month = int.parse(monthPart);
      int day = int.parse(dayPart);
      return "$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}";
    }
    return "Unknown";
  }
  Widget _buildAttendanceHeader() {
    final allDaysExcluded = studentData?['allDaysExcluded'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueAccent,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 90,
            lineWidth: 12,
            animation: true,
            percent:  allDaysExcluded ? 1.0 : attendancePercentage / 100,
            center: Text(
              "$attendancePercentage%",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.white,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            allDaysExcluded? "All Days Excluded":"Attendance Progress", // New
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    // Add a check for allDaysExcluded *specifically* for the attendance row
    if (label == "Attendance Status" && studentData?['allDaysExcluded'] == true) {
      value = "100%"; // Override the value
      valueColor = Colors.green[800]; // A  color
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDetailsCard() {
    if (studentData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              "No student records found",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    final allDaysExcluded = studentData?['allDaysExcluded'] == true;
    final fullName = "${studentData!['first_name'] ?? 'N/A'} ${studentData!['last_name'] ?? 'N/A'}";
    final stuId = studentData!['student_id'] ?? 'N/A';
    final natId = studentData!['national_id'] ?? 'N/A';
    final birthday = getBirthday(natId);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person_outline, "Student Name", fullName),
            _buildDetailRow(Icons.badge_outlined, "Student ID", stuId),
            _buildDetailRow(Icons.fingerprint_outlined, "National ID", natId),
            _buildDetailRow(Icons.cake_outlined, "Date of Birth", birthday),
            const Divider(height: 32),
            _buildDetailRow(
              Icons.verified_user_outlined,
              "Attendance Status",
              allDaysExcluded ? "100%" : "$attendancePercentage%",
              valueColor: allDaysExcluded ?  Colors.green[800]! : _getAttendanceColor(attendancePercentage), // set appropriate color
            ),
          ],
        ),
      ),
    );
  }
  Color _getAttendanceColor(int percentage) {
    if (percentage >= 90) return Colors.green[800]!;
    if (percentage >= 75) return Colors.orange[800]!;
    return Colors.red[800]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Student Report", // Keep this concise
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color:  Colors.deepPurple,))
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: GoogleFonts.inter(color: Colors.red)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAttendanceHeader(),
            const SizedBox(height: 32),
            _buildStudentDetailsCard(), // Now correctly receives the data and builds the card
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
// lib/Admin/Evaluation/AdvancedEvaluationAdminScreen.dart
import 'package:attendance_sys/Admin/pdf_service_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart'; // For graphical visualization
import 'package:printing/printing.dart'; // Import for printing


class AdvancedEvaluationAdminScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  final String studentId; // The student's UUID from the student_rounds record

  const AdvancedEvaluationAdminScreen({
    Key? key,
    required this.round,
    required this.studentId,

  }) : super(key: key);

  @override
  State<AdvancedEvaluationAdminScreen> createState() =>
      _AdvancedEvaluationAdminScreenState();
}

class _AdvancedEvaluationAdminScreenState extends State<AdvancedEvaluationAdminScreen> {
  bool isLoading = true;
  Map<String, dynamic>? studentStat;
  String _supervisorName = "N/A";
  String _trainingCenterName = "N/A";
  String _trainingCenterLocation = "N/A";

  @override
  void initState() {
    super.initState();
    _fetchStudentStatistics();
  }

  Future<void> _fetchStudentStatistics() async {
    setState(() {
      isLoading = true;
    });

    try {
      final roundId = widget.round['id'];
      final startDate = DateTime.parse(widget.round['start_date']);
      final endDate = DateTime.parse(widget.round['end_date']);
      int expectedDays = endDate.difference(startDate).inDays + 1;// use int

      // Fetch *only* the attendance records for this specific round and student.
      final attendanceResponse = await Supabase.instance.client
          .from('attendance')
          .select('scanned_date')
          .eq('round_id', roundId) // Use the round ID
          .eq('student_id', widget.studentId);  // Use the student ID

      // Count the unique attendance days
      Set<String> uniqueDates = {};
      for (var record in attendanceResponse) {
        if (record['scanned_date'] != null) {
          uniqueDates.add(record['scanned_date'].toString());
        }
      }
      final attendedDays = uniqueDates.length;

      // Fetch and subtract excluded dates.
      final excludedDatesResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', roundId);

      // Convert to a set of DateTime objects for efficient checking
      Set<DateTime> excludedDates = (excludedDatesResponse as List)
          .map((item) => DateTime.parse(item['date']).toLocal())
          .toSet();
      int excludedDaysCount = 0;
      for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
        if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {
          excludedDaysCount++;
        }
      }
      int actualExpectedDays = expectedDays - excludedDaysCount; //should be int

      bool allDaysExcluded = false; // New flag
      if (actualExpectedDays == 0) {
        allDaysExcluded = true; // Set the flag
        actualExpectedDays =1;
      }

      //change here with condition
      final attendancePercentage = actualExpectedDays > 0
          ? ((attendedDays / actualExpectedDays) * 100).round()
          : 100;


      // Fetch student profile from `profiles` using the passed studentId
      final studentResponse = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, student_id, national_id')
          .eq('id', widget.studentId) // Use the passed studentId
          .maybeSingle(); // Use maybeSingle


      if (studentResponse == null) {
        setState(() {
          studentStat = null; // Set to null if no student data
          isLoading = false;
        });
        return;
      }

      // Combine necessary data.
      setState(() {
        studentStat = {
          ...studentResponse,  // This is now the DIRECT profile data.
          'attendancePercentage': allDaysExcluded? 100 : attendancePercentage,
          'attendedDays': attendedDays, // Store these for display
          'expectedDays': expectedDays, // Store the *adjusted* expected days
          'allDaysExcluded': allDaysExcluded, // Store the flag

        };
      });

      await _fetchRoundExtraDetails();  // Fetch supervisor, center info

    } catch (e) {
      print("Error fetching student statistics: $e");
      setState(() {
        isLoading = false;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Fetch additional details: supervisor and training center info.
  Future<void> _fetchRoundExtraDetails() async {
    try {
      if (widget.round['leader_id'] != null) {
        final supervisorResponse = await Supabase.instance.client
            .from('supervisors')
            .select('first_name, last_name, training_center_id')
            .eq('id', widget.round['leader_id'])
            .maybeSingle();

        if (supervisorResponse != null) {
          setState(() {
            _supervisorName =
                "${supervisorResponse['first_name']?.toString() ?? ''} ${supervisorResponse['last_name']?.toString() ?? ''}"
                    .trim();
          });
          if (supervisorResponse['training_center_id'] != null) {
            final tcResponse = await Supabase.instance.client
                .from('training_centers')
                .select('name')
                .eq('id', supervisorResponse['training_center_id'])
                .maybeSingle();
            if (tcResponse != null) {
              setState(() {
                _trainingCenterName = tcResponse['name']?.toString() ?? "N/A";
              });
            }
          }
        }
      }
      setState(() {
        _trainingCenterLocation =
            widget.round['location']?.toString() ?? "N/A";
      });
    } catch (e) {
      print("Error fetching round extra details: $e");
    }
  }

  /// Compute birthday from a national id.
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

  /// Build the attendance header.
  Widget _buildAttendanceHeader() {
    final percentage = studentStat?['attendancePercentage'] ?? 0;
    final allDaysExcluded = studentStat?['allDaysExcluded'] == true; // Get the flag
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
            percent: allDaysExcluded ? 1.0 : percentage / 100,  // Corrected percentage
            center: Text(
              "$percentage%",
              // allDaysExcluded ? "N/A" : "$percentage%", // Show "N/A" or the percentage
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
            allDaysExcluded ? "All Days Excluded": "Attendance Progress", // New
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


  /// Build a label-value row.
  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
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

  /// Build the student details card.
  Widget _buildStudentDetailsCard() {
    // Access student details directly from studentStat
    if (studentStat == null) {
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

    final fullName =
        "${studentStat!['first_name']?.toString() ?? 'N/A'} ${studentStat!['last_name']?.toString() ?? 'N/A'}";
    final stuId = studentStat!['student_id']?.toString() ?? 'N/A';
    final natId = studentStat!['national_id']?.toString() ?? 'N/A';
    final birthday = getBirthday(natId);
    final attendancePercentage = studentStat?['attendancePercentage'] ?? 0;
    final allDaysExcluded = studentStat?['allDaysExcluded'] == true;


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
              allDaysExcluded ? "100%" : "$attendancePercentage%", // Conditionally show
              valueColor: allDaysExcluded? Colors.green[800] : _getAttendanceColor(attendancePercentage), // green if excluded
            ),
          ],
        ),
      ),
    );
  }

  /// Build training center information.
  Widget _buildTrainingCenterInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Training Center Details",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.school_outlined, "Center Name", _trainingCenterName),
          _buildDetailRow(Icons.location_on_outlined, "Location", _trainingCenterLocation),
          _buildDetailRow(Icons.supervisor_account_outlined, "Supervisor", _supervisorName),
        ],
      ),
    );
  }

  Color _getAttendanceColor(int percentage) {
    if (percentage >= 90) return Colors.green[800]!;
    if (percentage >= 75) return Colors.orange[800]!;
    return Colors.red[800]!;
  }

  /// Build attendance statistics for all rounds. Removed.
  Future<void> _generatePdf() async {
    final student = studentStat ?? {};
    final round = widget.round;
    final attendancePercentage = studentStat?['attendancePercentage'] ?? 0;

    final ByteData leftData = await rootBundle.load('assets/pharmacy.png');
    final Uint8List leftLogoBytes = leftData.buffer.asUint8List();

    final ByteData rightData = await rootBundle.load('assets/ImageHandler.png'); // Corrected asset path
    final Uint8List rightLogoBytes = rightData.buffer.asUint8List();
    final qrCodeData =
        "reportType:single|studentId:${widget.studentId}|roundId:${widget.round['id']}"; // Construct QR data

    final pdfData = await PdfServiceAdmin.generateReport(
      student: student,
      round: round,
      attendancePercentage: attendancePercentage,
      trainingCenterName: _trainingCenterName,
      trainingCenterLocation: _trainingCenterLocation,
      supervisorName: _supervisorName,
      leftLogoBytes: leftLogoBytes,
      rightLogoBytes: rightLogoBytes,
      qrCodeData: qrCodeData, // Pass the QR code data

    );

    await Printing.layoutPdf(onLayout: (format) async => pdfData);
  }

  @override
  Widget build(BuildContext context) {
    final roundName = widget.round['name']?.toString() ?? "Round Details";
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Advanced Evaluation - $roundName",
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
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
          )
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A)),
          strokeWidth: 3,
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchStudentStatistics,
        color: const Color(0xFF6A1B9A),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAttendanceHeader(),
              const SizedBox(height: 32),
              _buildStudentDetailsCard(), // This now correctly receives the data
              const SizedBox(height: 24),
              _buildTrainingCenterInfo(),
              const SizedBox(height: 32),
              // Removed
            ],
          ),
        ),
      ),
    );
  }
}
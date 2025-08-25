// lib/Student/AllRoundsReportScreen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart'; // For printing
import 'pdf_service_student.dart';

class AllRoundsReportScreen extends StatefulWidget {
  final String studentId;

  const AllRoundsReportScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<AllRoundsReportScreen> createState() => _AllRoundsReportScreenState();
}

class _AllRoundsReportScreenState extends State<AllRoundsReportScreen> {
  bool isLoading = true;
  Map<String, dynamic>? studentData;
  List<Map<String, dynamic>> roundsData = [];
  int _cumulativeAttendancePercentage = 0; // NEW: Store the overall percentage

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch student profile
      final studentResponse = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, student_id, national_id')
          .eq('id', widget.studentId)
          .maybeSingle();

      if (studentResponse == null) {
        throw Exception("Student not found");
      }

      // Fetch all rounds the student is enrolled in
      final enrolledRoundsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id, rounds(id, name, start_date, end_date, leader_id, location)') // Fetch all round details
          .eq('student_id', widget.studentId);

      List<Map<String, dynamic>> enrolledRounds = List<Map<String, dynamic>>.from(enrolledRoundsResponse);

      // NEW: Initialize cumulative counters
      int totalAttendedDays = 0;
      int totalExpectedDays = 0;

      // Fetch attendance data and calculate statistics for each round
      for (var enrollment in enrolledRounds) {
        final round = enrollment['rounds'];
        final roundId = round['id'];
        final startDate = DateTime.parse(round['start_date']);
        final endDate = DateTime.parse(round['end_date']);
        int expectedDays = endDate.difference(startDate).inDays + 1; // Initial calculation

        // --- EXCLUDED DATES LOGIC ---
        final excludedDatesResponse = await Supabase.instance.client
            .from('excluded_dates')
            .select('date')
            .eq('round_id', roundId);

        // Convert to a set of DateTime objects
        Set<DateTime> excludedDates = (excludedDatesResponse as List)
            .map((item) => DateTime.parse(item['date']).toLocal()) // to Local HERE
            .toSet();

        int excludedDaysCount = 0;
        for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
          if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {  // Only compare YYYY-MM-DD
            excludedDaysCount++;
          }
        }

        // Adjust expectedDays
        expectedDays -= excludedDaysCount;
        // --- END EXCLUDED DATES LOGIC ---

        bool allDaysExcluded = false; // Initialize the flag

        if (expectedDays == 0) {
          allDaysExcluded = true;
          // expectedDays = 1;  //Remove this
        }



        final attendanceResponse = await Supabase.instance.client
            .from('attendance')
            .select('scanned_date')
            .eq('round_id', roundId)
            .eq('student_id', widget.studentId);

        final attendedDays = (attendanceResponse as List).length;

        //CHANGE HERE
        final attendancePercentage = expectedDays > 0
            ? ((attendedDays / expectedDays) * 100).round()
            : 100;


        // NEW: Add to cumulative totals, use  max to compare values with and return that of the largest value.
        totalAttendedDays += attendedDays;
        totalExpectedDays += expectedDays > 0 ? expectedDays : 0;

        // Fetch Supervisor Name
        String supervisorName = "N/A"; // Default value
        if (round['leader_id'] != null) {
          final supervisorResponse = await Supabase.instance.client
              .from('supervisors')
              .select('first_name, last_name')
              .eq('id', round['leader_id'])
              .maybeSingle(); // Use maybeSingle since it's a single record

          if (supervisorResponse != null) {
            supervisorName = "${supervisorResponse['first_name']} ${supervisorResponse['last_name']}";
          }
        }

        // Store all the round and attendance data
        round['attendedDays'] = attendedDays;
        round['expectedDays'] = expectedDays; // Updated expectedDays
        round['attendancePercentage'] = attendancePercentage;
        round['allDaysExcluded'] = allDaysExcluded; // Store allDaysExcluded
        round['supervisorName'] = supervisorName; // Add supervisor name

        roundsData.add(round);
      }
      //NEW calculate over all:
      // Calculate cumulative percentage
      _cumulativeAttendancePercentage = totalExpectedDays > 0? ((totalAttendedDays / totalExpectedDays) * 100).round()
          : 100;
      setState(() {
        studentData = studentResponse;
        isLoading = false;
      });

    } catch (e) {
      print("Error fetching report data: $e");
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

  Future<void> _generatePdf() async {
    final student = studentData ?? {};
    final rounds = roundsData; // Pass the *list* of rounds

    final ByteData leftData = await rootBundle.load('assets/pharmacy.png');
    final Uint8List leftLogoBytes = leftData.buffer.asUint8List();

    final ByteData rightData = await rootBundle.load('assets/ImageHandler.png');
    final Uint8List rightLogoBytes = rightData.buffer.asUint8List();

    // Construct QR code data, add the report type:
    final qrCodeData = "reportType:all|studentId:${widget.studentId}";

    final pdfData = await PdfServiceStudent.generateReport(
      student: student,
      rounds: rounds,
      getBirthday: getBirthday,
      leftLogoBytes: leftLogoBytes,
      rightLogoBytes: rightLogoBytes,
      qrCodeData: qrCodeData, // Pass QR code data
    );

    await Printing.layoutPdf(onLayout: (format) async => pdfData);
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {

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
    final fullName =
        "${studentData!['first_name']?.toString() ?? 'N/A'} ${studentData!['last_name']?.toString() ?? 'N/A'}";
    final stuId = studentData!['student_id']?.toString() ?? 'N/A';
    final natId = studentData!['national_id']?.toString() ?? 'N/A';
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
            _buildDetailRow( //To show overall attendance, by its value:
              Icons.all_inclusive,
              "Cumulative Attendance (All Rounds)",
              "$_cumulativeAttendancePercentage%", // Use the stored overall percentage
              valueColor: _getAttendanceColor(_cumulativeAttendancePercentage), //Apply Color: green, red and orange.
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildAttendanceHeader() {
    // final percentage = studentStat?['attendancePercentage'] ?? 0;
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
          // NEW: Cumulative Attendance
          CircularPercentIndicator(
            radius: 90,
            lineWidth: 12,
            animation: true,
            percent:  _cumulativeAttendancePercentage / 100,
            center: Text(
              "$_cumulativeAttendancePercentage%",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.amberAccent, // Different color for distinction
            backgroundColor: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            "Cumulative Attendance (All Rounds)",

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "All Rounds Report",
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap the attendance header in a Center widget to center it horizontally.
            Center(child: _buildAttendanceHeader()),
            const SizedBox(height: 24),
            _buildStudentDetailsCard(), // Display student details at the top.
            const SizedBox(height: 24),
            Text(
              "Rounds and Attendance",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            if (roundsData.isEmpty)
              Center(
                child: Text(
                  "No rounds found.",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              )
            else
              ...roundsData.map((round) => _buildRoundCard(round)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              round['name'] ?? "Unnamed Round",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(round['start_date']))}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              "End Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(round['end_date']))}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              "Location: ${round['location'] ?? 'N/A'}",
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 4),
            // Supervisor information.
            Text(
              "Supervisor: ${round['supervisorName'] ?? 'N/A'}",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Colors.grey), // Visual separator
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Attendance: ${round['attendedDays']} / ${round['expectedDays']} days",
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                CircularPercentIndicator(
                  radius: 40,
                  lineWidth: 8,
                  percent: round['attendancePercentage'] / 100,
                  center: Text(
                    "${round['attendancePercentage']}%",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getAttendanceColor(round['attendancePercentage']),
                    ),
                  ),
                  progressColor: _getAttendanceColor(round['attendancePercentage']),
                  backgroundColor: Colors.grey[300]!,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAttendanceColor(int percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }
}
// lib/Student/AdvancedEvaluationScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:printing/printing.dart';
import 'pdf_service_student_single.dart'; // Use the *single* round PDF service


class AdvancedEvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  final String studentId;

  const AdvancedEvaluationScreen({
    Key? key,
    required this.round,
    required this.studentId,
  }) : super(key: key);

  @override
  State<AdvancedEvaluationScreen> createState() =>
      _AdvancedEvaluationScreenState();
}

class _AdvancedEvaluationScreenState extends State<AdvancedEvaluationScreen> {
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
    // ... (rest of your _fetchStudentStatistics function remains the same)
    // ... (make sure you calculate  'attendedDays', 'expectedDays', and 'allDaysExcluded')

    setState(() {
      isLoading = true;
    });

    try {
      final roundId = widget.round['id'];

      // Safely retrieve and convert start and end dates, Change is int
      final String? startDateStr = widget.round['start_date']?.toString();
      final String? endDateStr = widget.round['end_date']?.toString();
      int expectedDays = 0;
      if (startDateStr != null && startDateStr.isNotEmpty && endDateStr != null && endDateStr.isNotEmpty) {
        DateTime startDate = DateTime.parse(startDateStr);
        DateTime endDate = DateTime.parse(endDateStr);
        expectedDays = endDate.difference(startDate).inDays + 1;
      }

      // Query attendance records for the student in this round.
      final attendanceResponse = await Supabase.instance.client
          .from('attendance')
          .select('scanned_date, round_id')
          .eq('student_id', widget.studentId);

      //Creating a map for store student attendance by round for attendedDays calculation.
      Map<String, Set<String>> attendanceByRound = {}; // Stores attendance per round

      for (var record in attendanceResponse) {
        if (record['scanned_date'] != null) {
          String roundId = record['round_id'];
          attendanceByRound.putIfAbsent(roundId, () => {});
          attendanceByRound[roundId]!.add(record['scanned_date'].toString());
        }
      }
      // Attendance for selected round
      int attendedDays = attendanceByRound[widget.round['id']]?.length ?? 0;



      // Fetch and subtract excluded dates.  THIS IS THE NEW PART.
      final excludedDatesResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', roundId);


      // Convert to a set of DateTime objects for efficient checking
      DateTime startDate = DateTime.parse(startDateStr!); //safe, checks in not null above
      DateTime endDate = DateTime.parse(endDateStr!);    //safe

      Set<DateTime> excludedDates = (excludedDatesResponse as List)
          .map((item) => DateTime.parse(item['date']).toLocal())  //  .toLocal()
          .toSet();
      int excludedDaysCount = 0;

      // Count excluded days *within the round's date range*.
      for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
        if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {
          excludedDaysCount++;
        }
      }

      // Calculate actual expected days
      int actualExpectedDays = expectedDays - excludedDaysCount;
      bool allDaysExcluded = false;

      if (actualExpectedDays == 0) {
        allDaysExcluded = true; // set attribute
        actualExpectedDays =1;
      }

      // Calculate correct percentage using actualExpectedDays.
      final attendancePercentage = actualExpectedDays > 0? ((attendedDays / actualExpectedDays) * 100).round() : 0;
      //If all days excluded
      if(allDaysExcluded){
        attendancePercentage == 100;
      }
      final studentResponse = await Supabase.instance.client
          .from('student_rounds')
          .select(
          'student_id, students(id, first_name, last_name, student_id, national_id)'
      )
          .eq('student_id', widget.studentId)
          .order('created_at', ascending: false) // Ensure we get the latest records first
          .limit(1); // Get at least one past round if available

      //Using Map to fix.
      if (studentResponse.isNotEmpty) {
        Map<String, dynamic> data = {'students': studentResponse.first['students']};
        data['attendancePercentage'] = attendancePercentage;
        data['allDaysExcluded'] = allDaysExcluded; // Add this data
        data['attendedDays'] = attendedDays;
        data['expectedDays'] = expectedDays; //actual days
        setState(() {
          studentStat = data; // This now has attendance and all attributes needed, excluded logic implemented and
          // storing new variables.

        });

      }else {
        setState(() { //Handle data
          studentStat = null; // Set to null if no student data
        });

      }

      // Fetch extra round details.
      await _fetchRoundExtraDetails();
    } catch (e) {
      print("Error fetching student statistics: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchRoundExtraDetails() async {
    // ... (rest of your _fetchRoundExtraDetails function)
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
      // Ensure training center location is a String.
      setState(() {
        _trainingCenterLocation =
            widget.round['location']?.toString() ?? "N/A";
      });
    } catch (e) {
      print("Error fetching round extra details: $e");
    }
  }

  String getBirthday(String? nationalId) {
    // ... (your getBirthday function - no changes needed)
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
    // ... (your _buildAttendanceHeader function - no changes needed)
    final percentage = studentStat?['attendancePercentage'] ?? 0;
    final allDaysExcluded = studentStat?['allDaysExcluded'] == true;
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
              allDaysExcluded? "100%": "$percentage%",
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

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    // ... (your _buildDetailRow function, you may want to adjust colors/text based on allDaysExcluded if needed)
    // Add a check for allDaysExcluded *specifically* for the attendance row
    if (label == "Attendance Status" && studentStat?['allDaysExcluded'] == true) {
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
    // ... (rest of _buildStudentDetailsCard - no changes needed)
    final student = studentStat?['students'];

    //print("Student data from data is ${student}");

    if (student == null) {
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
        "${student['first_name']?.toString() ?? 'N/A'} ${student['last_name']?.toString() ?? 'N/A'}";
    final stuId = student['student_id']?.toString() ?? 'N/A';
    final natId = student['national_id']?.toString() ?? 'N/A';
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
              allDaysExcluded ? "100%" : "$attendancePercentage%",//call it here.
              valueColor: allDaysExcluded ?  Colors.green[800]! : _getAttendanceColor(attendancePercentage), // set appropriate color
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingCenterInfo() {
    // ... (your _buildTrainingCenterInfo function - no changes needed)
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

  Future<void> _generatePdf() async {
    final student = studentStat?['students'] ?? {};
    final round = widget.round;
    final attendancePercentage = studentStat?['attendancePercentage'] ?? 0;
    final allDaysExcluded = studentStat?['allDaysExcluded'] == true;

    // Construct the QR code data.  This is for a *single* round.
    final qrCodeData = "reportType:single|studentId:${widget.studentId}|roundId:${widget.round['id']}";

    final ByteData leftData = await rootBundle.load('assets/pharmacy.png');
    final Uint8List leftLogoBytes = leftData.buffer.asUint8List();

    final ByteData rightData = await rootBundle.load('assets/ImageHandler.png');
    final Uint8List rightLogoBytes = rightData.buffer.asUint8List();

    final pdfData = await PdfServiceStudentSingle.generateReport( // Use the single-round service
      student: student,
      round: round,
      attendancePercentage: allDaysExcluded? 100 : attendancePercentage, // Pass the percentage
      trainingCenterName: _trainingCenterName,
      trainingCenterLocation: _trainingCenterLocation,
      supervisorName: _supervisorName,
      getBirthday: getBirthday,
      leftLogoBytes: leftLogoBytes,
      rightLogoBytes: rightLogoBytes,
      qrCodeData: qrCodeData,
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
            ],
          ),
        ),
      ),
    );
  }
}
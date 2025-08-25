import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class StudentDetailsScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailsScreen({Key? key, required this.studentId})
      : super(key: key);

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  bool isLoading = true;
  Map<String, dynamic>? studentData;
  List<Map<String, dynamic>> enrolledRounds = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch student details from profiles.
      final studentResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, first_name, last_name, student_id, national_id, status')
          .eq('id', widget.studentId)
          .single();

      // Fetch enrolled rounds using the student_rounds table.
      final roundsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('rounds(name, start_date, end_date)')
          .eq('student_id', widget.studentId);

      setState(() {
        studentData = studentResponse;
        enrolledRounds = List<Map<String, dynamic>>.from(roundsResponse);
      });
    } catch (e) {
      print("Error fetching student details: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Format date to "DD-MM-YYYY"
  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return "Invalid Date";
    }
  }

  Widget _buildRoundTile(Map<String, dynamic> round) {
    final roundInfo = round['rounds'] ?? {};
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          roundInfo['name'] ?? "Unknown Round",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Duration: ${formatDate(roundInfo['start_date'] ?? "")} to ${formatDate(roundInfo['end_date'] ?? "")}",
          style: GoogleFonts.inter(fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a gradient AppBar for consistent styling.
      appBar: AppBar(
        title: Text(
          "Student Details",
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : studentData == null
          ? Center(
        child: Text(
          "Student not found.",
          style: GoogleFonts.cairo(fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Information Card
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              shadowColor: Colors.deepPurple.withOpacity(0.1),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text(
                  "${studentData!['first_name']} ${studentData!['last_name']}",
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      "Student ID: ${studentData!['student_id']}",
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "National ID: ${studentData!['national_id']}",
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Status: ${studentData!['status']}",
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Enrolled Rounds Title
            Text(
              "Enrolled Rounds",
              style: GoogleFonts.cairo(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Display enrolled rounds if any.
            enrolledRounds.isEmpty
                ? Text(
              "No enrolled rounds.",
              style: GoogleFonts.inter(fontSize: 14),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: enrolledRounds.length,
                itemBuilder: (context, index) {
                  return _buildRoundTile(enrolledRounds[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

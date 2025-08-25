import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupervisorRoundStudents extends StatefulWidget {
  final Map<String, dynamic> round;

  const SupervisorRoundStudents({Key? key, required this.round})
      : super(key: key);

  @override
  State<SupervisorRoundStudents> createState() =>
      _SupervisorRoundStudentsState();
}

class _SupervisorRoundStudentsState extends State<SupervisorRoundStudents> {
  bool isLoading = true;
  List<Map<String, dynamic>> studentRounds = [];

  @override
  void initState() {
    super.initState();
    _fetchRoundStudents();
  }

  Future<void> _fetchRoundStudents() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select(
          'student_id, round_id, status, profiles!fk_student_rounds_profiles(first_name, last_name, email, student_id)')
          .eq('round_id', widget.round['id'])
          .eq('status', 'in_progress'); // Add this line
      print("Fetched student_rounds response: $response");

      // Create a set to store distinct student IDs
      Set<String> studentIds = {};

      // Use a list to store the processed student data
      List<Map<String, dynamic>> processedStudents = [];

      for (final record in response) {
        final studentId = record['student_id'] as String?;
        if (studentId != null &&
            !studentIds.contains(studentId)) { // Check for duplicates using ID
          studentIds.add(studentId); // Add to the set to track
          processedStudents.add({
            'student_id':
            studentId, // Keep the student_id for potential later use
            'round_id': record['round_id'],
            'status': record['status'],
            'profile': {
              // Access profiles data safely
              'first_name': record['profiles']['first_name'] ?? 'Unknown',
              'last_name': record['profiles']['last_name'] ?? '',
              'email': record['profiles']['email'] ?? 'No Email',
              'student_id': record['profiles']['student_id'] ?? 'No Student ID',
            },
          });
        }
      }

      setState(() {
        studentRounds =
            processedStudents; // Update with processed, de-duplicated data
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching round students: $e");
      setState(() {
        // Set loading to false EVEN on error.
        isLoading = false; // IMPORTANT:  Don't leave the UI stuck loading.
      });
    }
  }

  Widget _buildStudentCard(Map<String, dynamic> record) {
    // Access profile data safely.  No need for extra casting.
    final profile = record['profile'];
    final studentName =
        "${profile['first_name'] ?? 'Unknown'} ${profile['last_name'] ?? ''}";
    final email = profile['email'] ?? 'No Email';
    final studId = profile['student_id'] ?? 'No Student ID';
    final status = record['status'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        title: Text(
          studentName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          "Email: $email\nStudent ID: $studId\nStatus: $status",
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roundName = widget.round['name'] ?? "Unnamed Round";
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Students for $roundName",
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
          : studentRounds.isEmpty
          ? Center(
        child: Text(
          "No students have selected this round yet.",
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: studentRounds.length,
        itemBuilder: (context, index) {
          return _buildStudentCard(studentRounds[index]);
        },
      ),
    );
  }
}
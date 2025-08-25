// lib/Admin/Evaluation/StudentsListScreen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Make sure this import is present
import 'AdvancedEvaluationAdminScreen.dart';

class StudentsListScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  final List<dynamic> students;

  const StudentsListScreen({
    Key? key,
    required this.round,
    required this.students,
  }) : super(key: key);

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  bool isLoading = true; // Add loading state
  List<Map<String, dynamic>> students = []; // Properly typed list

  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents(); // Fetch data on init
  }

  Future<void> _fetchEnrolledStudents() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Join student_rounds with profiles to get student details,
      // SPECIFYING the correct foreign key relationship.
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('student_id, profiles!fk_student(first_name, last_name, student_id)') // Corrected join
          .eq('round_id', widget.round['id'])
          .eq('status', 'in_progress');

      print("StudentsListScreen: students data: $response");


      // Create a set to store distinct student IDs
      Set<String> studentIds = {};

      // Use a list to store the processed student data
      List<Map<String, dynamic>> processedStudents = [];

      for (final record in response) {
        final studentId = record['student_id'] as String?;
        if (studentId != null && !studentIds.contains(studentId)) { // Check for duplicates using ID
          studentIds.add(studentId); // Add to the set to track
          processedStudents.add({
            'id': studentId,  // Corrected line
            'first_name': record['profiles']['first_name'] ?? 'Unknown',
            'last_name': record['profiles']['last_name'] ?? '',
            'student_id': record['profiles']['student_id'] ?? 'N/A',
          });
        }
      }


      setState(() {
        students = processedStudents;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching enrolled students: $e");
      setState(() { // ALSO set state on error
        isLoading = false; // Set loading to false on error.
      });
    }
  }

  void _navigateToAdvancedEvaluation(BuildContext context, Map<String, dynamic> studentEntry) {
    // The student ID is now directly in the studentEntry, not nested.
    final studentUuid = studentEntry['id']?.toString() ?? ''; // Corrected line
    print("Student UUID being passed: $studentUuid"); // Keep this!
    print("Round being passed: ${widget.round}");   // Keep this!


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedEvaluationAdminScreen(
          round: widget.round,
          studentId: studentUuid, // Pass the correct student ID
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    print("StudentsListScreen: students data: $students"); // Keep for debugging
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Students in ${widget.round['name']?.toString() ?? 'Round'}",
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
      body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
            ),
          ),
          child: isLoading // Show loading indicator
              ? const Center(child: CircularProgressIndicator(color:  Colors.deepPurple,))
              :  students.isEmpty?  // Add Empty check
          Center(
            child: Text(
              "No students found", // More concise message
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
            ),
          ) : ListView.separated(  //Corrected to ListView.separated

            padding: const EdgeInsets.all(20),
            itemCount: students.length, // Number of students
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = students[index];
              final Map<String, dynamic> student;

              if (entry.containsKey('profiles')) {
                // From AdminManageRounds
                student = entry['profiles'] as Map<String, dynamic>;
              }
              else {
                //From AllStudentsReportListScreen
                student = entry;
              }


              final displayStudentId = student['student_id']?.toString() ?? 'N/A';
              final firstName = student['first_name']?.toString() ?? 'N/A';
              final lastName = student['last_name']?.toString() ?? 'N/A';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.deepPurple.withOpacity(0.1),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.deepPurple[800],
                    ),
                  ),
                  title: Text(
                    "$firstName $lastName",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  subtitle: Text(
                    "ID: $displayStudentId",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.deepPurple[800],
                  ),
                  onTap: () => _navigateToAdvancedEvaluation(context, entry),
                ),
              );
            },
          )
      ),
    );
  }
}
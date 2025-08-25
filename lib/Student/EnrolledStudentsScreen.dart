import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrolledStudentsScreen extends StatefulWidget {
  final String roundId;

  const EnrolledStudentsScreen({Key? key, required this.roundId})
      : super(key: key);

  @override
  State<EnrolledStudentsScreen> createState() => _EnrolledStudentsScreenState();
}

class _EnrolledStudentsScreenState extends State<EnrolledStudentsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> enrolledStudents = [];

  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents();
  }

  /// Fetch enrolled students with their names from the `profiles` table.
  Future<void> _fetchEnrolledStudents() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Query to join `student_rounds` with the `profiles` table.
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('*, profiles!fk_student(first_name, last_name, email, student_id)')
          .eq('round_id', widget.roundId);


      setState(() {
        enrolledStudents = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Error fetching enrolled students: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Builds a student tile displaying the student's name and email.
  Widget _buildStudentTile(Map<String, dynamic> studentRound) {
    final studentProfile = studentRound['profiles'];
    String studentName = "Unknown Student";
    if (studentProfile != null) {
      studentName =
          "${studentProfile['first_name'] ?? ''} ${studentProfile['last_name'] ?? ''}".trim();
    }
    String email = studentProfile != null ? (studentProfile['email'] ?? "") : "";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.deepPurple),
        title: Text(
          studentName.isNotEmpty ? studentName : "Unknown Student",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          email,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
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
          "Enrolled Students",
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
          ? const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      )
          : enrolledStudents.isEmpty
          ? Center(
        child: Text(
          "No students enrolled in this round.",
          style: GoogleFonts.cairo(fontSize: 16),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchEnrolledStudents,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: enrolledStudents.length,
          itemBuilder: (context, index) {
            return _buildStudentTile(enrolledStudents[index]);
          },
        ),
      ),
    );
  }
}

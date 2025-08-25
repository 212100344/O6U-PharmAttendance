import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SupervisorStudentReportDetailScreen.dart';

class SupervisorRoundStudentsReportScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  const SupervisorRoundStudentsReportScreen({Key? key, required this.round}) : super(key: key);

  @override
  State<SupervisorRoundStudentsReportScreen> createState() => _SupervisorRoundStudentsReportScreenState();
}

class _SupervisorRoundStudentsReportScreenState extends State<SupervisorRoundStudentsReportScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> studentRounds = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('student_id, profiles!fk_student(first_name, last_name, email, student_id)')
          .eq('round_id', widget.round['id']); // Use widget.round['id']

      setState(() {
        studentRounds = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching students: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildStudentCard(Map<String, dynamic> record) {
    final profile = record['profiles'] ?? {}; // Safely access 'profiles'
    final fullName = "${profile['first_name'] ?? 'Unknown'} ${profile['last_name'] ?? ''}";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          fullName,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "ID: ${profile['student_id'] ?? 'N/A'}", // Show Student ID
          style: GoogleFonts.inter(fontSize: 14),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupervisorStudentReportDetailScreen(
                studentId: record['student_id'],
                roundId: widget.round['id'], // Pass the round ID
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.round['name'] ?? "Round Students", // Show round name
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: GoogleFonts.inter(color: Colors.red)))
          : studentRounds.isEmpty
          ? Center(child: Text("No students enrolled", style: GoogleFonts.inter()))
          : RefreshIndicator(
        onRefresh: _fetchStudents,
        child: ListView.builder(
          itemCount: studentRounds.length,
          itemBuilder: (context, index) {
            return _buildStudentCard(studentRounds[index]);
          },
        ),
      ),
    );
  }
}
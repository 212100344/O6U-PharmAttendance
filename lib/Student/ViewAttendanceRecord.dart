import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'RoundAttendanceScreen.dart'; // Import the new screen

class ViewAttendanceRecord extends StatefulWidget {
  final String studentEmail;

  const ViewAttendanceRecord({Key? key, required this.studentEmail})
      : super(key: key);

  @override
  State<ViewAttendanceRecord> createState() => _ViewAttendanceRecordState();
}

class _ViewAttendanceRecordState extends State<ViewAttendanceRecord> {
  List<Map<String, dynamic>> rounds = [];
  bool isLoading = true;
  String? errorMessage;
  String? studentId; // Store the student ID

  @override
  void initState() {
    super.initState();
    _fetchStudentId(); // Fetch the student ID when the screen loads. *FIRST*
    _fetchRounds();     // *THEN* fetch rounds.
  }

  // MODIFIED _fetchStudentId
  Future<void> _fetchStudentId() async {
    try {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .ilike('email', widget.studentEmail) //use email correctly
          .single();
      setState(() {
        studentId = profileResponse['id'] as String?;
        isLoading = false;  // Correct place for isLoading = false;
        _fetchRounds();// fetch rounds AFTER ID fetched

      });
    } catch (e) {
      print("Error fetching student ID: $e"); // Or, show a Toast/Snackbar
      setState(() {
        isLoading = false;  // Ensure UI isn't stuck loading
        errorMessage = "Failed to load student data";
      });
    }
  }

  Future<void> _fetchRounds() async {
    if (studentId == null) {
      //  If no ID do nothing
      return;
    }
    //No need for SetState for isLoadind and message error

    try {
      // Get rounds the student is enrolled in, with round details.
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id, rounds(name, start_date, end_date)')
          .eq('student_id', studentId!);  // Use fetched studentId


      setState(() {
        rounds = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        errorMessage = "❌ Error fetching rounds: $e";
      });
    }
  }

  void _navigateToRoundDetails(Map<String, dynamic> round) {
    if (studentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoundAttendanceScreen(round: round, studentId: studentId!),//OK
        ),
      );
    } else {

      // Handle null ID case!  This is CRUCIAL for preventing errors
      // The user will now get immediate feedback.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Student ID not available.")),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Select Round",
          style: GoogleFonts.cairo(
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
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView.builder(
          itemCount: rounds.length,
          itemBuilder: (context, index) {
            final round = rounds[index];
            final roundDetails = round['rounds'];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: Colors.deepPurple.withOpacity(0.1),
              child: ListTile(
                onTap: () => _navigateToRoundDetails(round),
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  Icons.calendar_today,
                  color: Colors.deepPurple[300],
                  size: 30,
                ),
                title: Text(
                  roundDetails['name'] ?? "Unnamed Round",
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "${DateFormat('dd MMM, yyyy').format(DateTime.parse(roundDetails['start_date']))} - ${DateFormat('dd MMM, yyyy').format(DateTime.parse(roundDetails['end_date']))}",
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../StudentsListScreen.dart';
import 'package:intl/intl.dart';  // Import the intl package


class FinalEvaluationScreenAdmin extends StatefulWidget {
  const FinalEvaluationScreenAdmin({Key? key}) : super(key: key);

  @override
  State<FinalEvaluationScreenAdmin> createState() =>
      _FinalEvaluationScreenAdminState();
}

class _FinalEvaluationScreenAdminState extends State<FinalEvaluationScreenAdmin> {
  List<Map<String, dynamic>> rounds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRounds();
  }

  Future<void> _fetchRounds() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client.from('rounds').select(
          '*'); //select all the attribute needed
      setState(() {
        rounds = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      // Consider showing an error message to the user here
    }
  }

  Future<void> _navigateToStudents(BuildContext context,
      Map<String, dynamic> round) async {
    try {
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select(
          'student_id, status, profiles!fk_student_rounds_profiles(first_name, last_name, student_id, national_id)')
          .eq('round_id', round['id']);

      if (response.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentsListScreen(round: round, students: response),
          ),
        );
      } else {
        // Handle case where there are no enrolled students, possibly navigate to a screen for past evaluations
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No students currently enrolled. Viewing past evaluations...",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentsListScreen(round: round, students: response),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error fetching students: ${e.toString()}",
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to format dates consistently
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy/MM/dd').format(date); // Format as "YYYY/MM/DD"
    } catch (e) {
      return 'Invalid Date';  // Handle invalid date formats gracefully
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Training Rounds",
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
        child: isLoading
            ? Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rounds.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final round = rounds[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: Colors.deepPurple.withOpacity(0.1),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.date_range_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  round['name'] ?? 'Unnamed Round',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Start: ${_formatDate(round['start_date'])}", // Use helper for start date
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      "End: ${_formatDate(round['end_date'])}",   // Use helper and correct key
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.deepPurple[800],
                ),
                onTap: () => _navigateToStudents(context, round),
              ),
            );
          },
        ),
      ),
    );
  }
}
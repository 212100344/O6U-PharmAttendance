import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'AdvancedEvaluationScreen.dart';
import 'AllRoundsReportScreen.dart'; // Import the new screen

class FinalEvaluationScreen extends StatefulWidget {
  final String studentId; // Logged-in student's id

  const FinalEvaluationScreen({Key? key, required this.studentId})
      : super(key: key);

  @override
  State<FinalEvaluationScreen> createState() => _FinalEvaluationScreenState();
}

class _FinalEvaluationScreenState extends State<FinalEvaluationScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> rounds = [];

  @override
  void initState() {
    super.initState();
    _fetchRoundsData();
  }

  Future<void> _fetchRoundsData() async {
    setState(() => isLoading = true);
    try {
      // Fetch  rounds that the student is enrolled in
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id, rounds(id, name, start_date, end_date, leader_id, location)') // Fetch all round details
          .eq('student_id', widget.studentId); // Get roundId
      //order by date
      List<Map<String, dynamic>> roundsData = (response as List).map((item) { // type cast
        final Map<String, dynamic> round = item['rounds'];
        final String roundId = item['round_id']; //get it from student_round, as a reference
        return {
          'id': roundId, // Use the actual round ID
          'name': round['name'],
          'start_date': round['start_date'],
          'end_date': round['end_date'],
          'leader_id': round['leader_id'], //keep it
          'location': round['location'],

        };
      }).toList();
      // For each round, compute attendance statistics for the logged-in student.
      for (var round in roundsData) {
        final roundId = round['id']; //id from map
        DateTime startDate = DateTime.parse(round['start_date']);
        DateTime endDate = DateTime.parse(round['end_date']);
        int expectedDays = endDate.difference(startDate).inDays + 1;

        // Fetch attendance records for this round for the logged-in student.
        final attendanceResponse = await Supabase.instance.client
            .from('attendance')
            .select('scanned_date')
            .eq('round_id', roundId)
            .eq('student_id', widget.studentId); // Using studentId from widget
        List attendanceRecords = attendanceResponse as List;

        // Fetch excluded dates for the round
        final excludedDatesResponse = await Supabase.instance.client
            .from('excluded_dates')
            .select('date')
            .eq('round_id', roundId);
        // Convert to a Set<DateTime> to check very fast excluded dates
        Set<DateTime> excludedDates = (excludedDatesResponse as List)
            .map((item) => DateTime.parse(item['date']).toLocal())
            .toSet();

        int excludedDaysCount = 0;
        for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
          if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {
            excludedDaysCount++; //count only days in a specified range of dates.
          }
        }

        // Extract unique scanned dates.
        Set<String> uniqueDates = attendanceRecords
            .map((record) => record['scanned_date'].toString())
            .toSet();
        int attendedDays = uniqueDates.length;

        // Compute attendance ratio and absence ratio.
        // Calculate actualExpectedDays (subtract excluded days)
        int actualExpectedDays = expectedDays - excludedDaysCount;
        // Handle all days excluded edge-case
        bool allDaysExcluded = (actualExpectedDays == 0);
        if (allDaysExcluded) {
          actualExpectedDays = 1; // Prevent zero
        }
        double attendanceRatio =
        actualExpectedDays > 0 ? attendedDays / actualExpectedDays : 0.0; //correct division
        //in previous edits i forget it :')
        if(allDaysExcluded){
          attendanceRatio = 1.0;
        }

        double absenceRatio = 1 - attendanceRatio;


        // Store computed values in the round map.
        round['expectedDays'] = expectedDays;
        round['attendedDays'] = attendedDays;
        round['attendanceRatio'] = attendanceRatio;
        round['absenceRatio'] = absenceRatio;
        round['allDaysExcluded'] = allDaysExcluded; // Store
      }
      if(mounted){ //check is mounted before setting state
        setState(() {
          rounds = roundsData;
        });

      }

    } catch (e) {
      print("Error fetching rounds data: $e");
      // Optionally show an error message to the user
    } finally {
      if (mounted) { // Check if the widget is still mounted before setting state.
        setState(() {
          isLoading = false; // Set loading to false in all cases
        });
      }

    }
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    double attendanceRatio = round['attendanceRatio'] ?? 0.0;
    double absenceRatio = round['absenceRatio'] ?? 0.0;
    bool allDaysExcluded = round['allDaysExcluded'] == true;

    String attendanceText = allDaysExcluded
        ? "Attendance: 100%"  //If all days were excluded
        : "Attendance: ${(attendanceRatio * 100).toStringAsFixed(1)}%, Absence: ${(absenceRatio * 100).toStringAsFixed(1)}%";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 3,
      child: ListTile(
        title: Text(
          round['name'] ?? "Unnamed Round",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          attendanceText, // Set a default empty
          style: GoogleFonts.inter(fontSize: 14),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvancedEvaluationScreen(
                round: round,
                studentId: widget.studentId,
              ),
            ),
          );
        },
      ),
    );
  }

  // Added Service Card Builder (consistent with other screens)
  Widget _buildServiceCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
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
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.deepPurple[800],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Final Evaluation",
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
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
      body: Column(  // Wrap in a Column
        children: [
          // NEW: All Rounds Report Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildServiceCard(
              icon: Icons.summarize, // Or any other suitable icon
              label: "All Rounds Report",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllRoundsReportScreen(studentId: widget.studentId),
                  ),
                );
              },
            ),
          ),

          // Existing Rounds List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchRoundsData,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : rounds.isEmpty
                  ? ListView( // Use ListView to allow scrolling
                children: [
                  SizedBox(height: 100,),
                  Center(
                    child: Text(
                      "No rounds available.",
                      style: GoogleFonts.cairo(fontSize: 16),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                itemCount: rounds.length,
                itemBuilder: (context, index) {
                  return _buildRoundCard(rounds[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'EnrolledStudentsScreen.dart'; // Import the new screen

class StudentSelectRound extends StatefulWidget {
  final String studentId; // Pass the student's UUID

  const StudentSelectRound({Key? key, required this.studentId})
      : super(key: key);

  @override
  State<StudentSelectRound> createState() => _StudentSelectRoundState();
}

class _StudentSelectRoundState extends State<StudentSelectRound> {
  bool isLoading = true;
  List<Map<String, dynamic>> rounds = [];
  String? activeRoundId; // Track the currently active round ID
  String? errorMessage; // To display fetch errors

  @override
  void initState() {
    super.initState();
    _fetchRoundsAndEnrollments();
  }

  Future<void> _fetchRoundsAndEnrollments() async {
    setState(() {
      isLoading = true;
      errorMessage = null; // Clear previous errors
    });

    try {
      // Step 1: Fetch rounds
      final roundsResponse = await Supabase.instance.client
          .from('rounds')
          .select('*')
          .order('start_date', ascending: true);

      List<Map<String, dynamic>> roundsData =
      List<Map<String, dynamic>>.from(roundsResponse);

      // Step 2: Fetch active rounds for this student (only need the ID)
      final activeRoundsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id')
          .eq('student_id', widget.studentId)
          .eq('status', 'in_progress') // Find the *current* active enrollment
          .maybeSingle(); // Expect 0 or 1 active enrollment

      // Step 3: Fetch supervisor names manually (can be optimized if needed)
      for (var round in roundsData) {
        if (round['leader_id'] != null) {
          try {
            final supervisorResponse = await Supabase.instance.client
                .from('supervisors')
                .select('first_name, last_name')
                .eq('id', round['leader_id'])
                .limit(1)
                .single();

            round['supervisor_name'] =
            "${supervisorResponse['first_name']} ${supervisorResponse['last_name']}";
          } catch (e) {
            print("Error fetching supervisor for round ${round['id']}: $e");
            round['supervisor_name'] = "N/A";
          }
        } else {
          round['supervisor_name'] = "N/A";
        }
      }

      setState(() {
        rounds = roundsData;
        // Set activeRoundId from the maybeSingle response
        activeRoundId = activeRoundsResponse?['round_id'] as String?;
      });
    } catch (e) {
      print("Error fetching rounds/enrollments: $e");
      if(mounted){
        setState(() {
          errorMessage = "Failed to load round data. Please try again.";
        });
      }
    } finally {
      if(mounted){
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _selectRound(Map<String, dynamic> round) async {

    // Ensure the student is not already enrolled in another round.
    if (activeRoundId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You are already enrolled in an active round.", // Clarified message
              style: GoogleFonts.inter()),
          backgroundColor: Colors.orange, // Use orange for warning
        ),
      );
      return;
    }

    // --- RE-CHECK ELIGIBILITY JUST BEFORE ENROLLING (using the same logic as button) ---
    final now = DateTime.now();
    final roundStartDate = DateTime.parse(round['start_date']);
    final roundEndDate = DateTime.parse(round['end_date']);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startDay = DateTime(roundStartDate.year, roundStartDate.month, roundStartDate.day);
    final DateTime endDay = DateTime(roundEndDate.year, roundEndDate.month, roundEndDate.day);

    if (today.isBefore(startDay) || today.isAfter(endDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This round is not currently active for enrollment.",
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // --- END RE-CHECK ---

    // Add loading state for enrollment action
    setState(() => isLoading = true);

    try {
      // Check again if already enrolled (race condition safety)
      final currentEnrollment = await Supabase.instance.client
          .from('student_rounds')
          .select('round_id')
          .eq('student_id', widget.studentId)
          .eq('status', 'in_progress')
          .maybeSingle();

      if (currentEnrollment != null) {
        // Update activeRoundId state if it was somehow missed earlier
        if(mounted) {
          setState(() {
            activeRoundId = currentEnrollment['round_id'];
          });
        }
        throw Exception("You are already enrolled in an active round.");
      }


      final newSelection = {
        'id': const Uuid().v4(),
        'student_id': widget.studentId,
        'round_id': round['id'],
        'status': 'in_progress', // Mark as active.
      };
      await Supabase.instance.client
          .from('student_rounds')
          .insert(newSelection); // Removed .select() - not needed for insert usually

      // Update the active round state *immediately* after successful insert
      if(mounted){
        setState(() {
          activeRoundId = round['id'];
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully enrolled in ${round['name']}",
              style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Display specific error from the catch block
      String displayError = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error enrolling: $displayError", style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Stop loading indicator regardless of success/failure
      if(mounted){
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    final now = DateTime.now();
    final roundStartDate = DateTime.parse(round['start_date']);
    final roundEndDate = DateTime.parse(round['end_date']);
    final bool isEnrolledInThisRound = activeRoundId == round['id']; // Check specifically *this* round

    // --- UPDATED ELIGIBILITY CHECK ---
    // Compare dates only (ignore time component)
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startDay = DateTime(roundStartDate.year, roundStartDate.month, roundStartDate.day);
    final DateTime endDay = DateTime(roundEndDate.year, roundEndDate.month, roundEndDate.day);

    // Eligible if today is on or after startDay AND on or before endDay
    final bool isEligibleForEnrollment =
        !today.isBefore(startDay) && !today.isAfter(endDay);
    // --- END UPDATE ---

    // Determine if the button should be shown: Not enrolled in *any* round yet, AND this round is eligible
    final bool canEnrollInThisRound = activeRoundId == null && isEligibleForEnrollment;


    String supervisorName = round['supervisor_name'] ?? "N/A";
    // No need for the extra check if supervisor_name is fetched correctly

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Round title and enrollment status.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded( // Allow title to wrap if needed
                  child: Text(
                    round['name'] ?? "Unnamed Round",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis, // Handle long names
                  ),
                ),
                const SizedBox(width: 8), // Add spacing
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Adjust padding
                  decoration: BoxDecoration(
                    color: isEnrolledInThisRound ? Colors.green.shade100 : (isEligibleForEnrollment ? Colors.blue.shade100 : Colors.grey.shade300) , // Different colors
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isEnrolledInThisRound ? "Enrolled" : (isEligibleForEnrollment ? "Available" : "Inactive"), // More descriptive status
                    style: GoogleFonts.inter(
                        color: isEnrolledInThisRound ? Colors.green.shade800 : (isEligibleForEnrollment ? Colors.blue.shade800 : Colors.grey.shade700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12 // Slightly smaller
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Round details.
            Text(
              "Duration: ${round['start_date'].toString().substring(0, 10)} to ${round['end_date'].toString().substring(0, 10)}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              "Location: ${round['location'] ?? 'N/A'}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            // Supervisor information.
            Text(
              "Supervisor: $supervisorName",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700] // Slightly darker for supervisor
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Always show "View Enrolled" if the round is active or you are enrolled
                if (isEnrolledInThisRound || isEligibleForEnrollment) // Show if enrolled OR eligible
                  TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EnrolledStudentsScreen(roundId: round['id']),
                          ),
                        );
                      },
                      icon: Icon(Icons.group_outlined, color: Colors.blue.shade700, size: 20), // Adjusted icon/color
                      label: Text(
                        "View Students", // Changed label
                        style: GoogleFonts.inter(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                      ),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8) // Adjust padding
                      )
                  ),
                // Show enroll button only if eligible and not already enrolled in *any* round
                if (canEnrollInThisRound)
                  ElevatedButton.icon(
                    onPressed: () => _selectRound(round),
                    icon: const Icon(Icons.check_circle_outline, size: 18), // Adjusted icon
                    label: Text(
                      "Enroll", // Shortened label
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600, // Darker green
                      foregroundColor: Colors.white, // White text
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Adjust padding
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Less rounded
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // Lighter background
      appBar: AppBar(
        title: Text(
          "Select Training Round", // More descriptive title
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
              colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)], // Keep gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4, // Slightly less elevation
        shadowColor: Colors.deepPurple.withOpacity(0.2),
      ),
      body: isLoading
          ? const Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurple,
          ))
          : errorMessage != null
          ? Center( // Show error message if fetch failed
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            errorMessage!,
            style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : rounds.isEmpty
          ? Center(
          child: Text(
            "No training rounds are available at this time.", // More user-friendly message
            style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ))
          : RefreshIndicator(
        onRefresh: _fetchRoundsAndEnrollments,
        color: Colors.deepPurple, // Indicator color
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), // Adjust list padding
          itemCount: rounds.length,
          itemBuilder: (context, index) {
            return _buildRoundCard(rounds[index]);
          },
        ),
      ),
    );
  }
}
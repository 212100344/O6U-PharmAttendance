import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'StudentDetailsScreen.dart'; // Import the student details screen
import 'package:uuid/uuid.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({Key? key}) : super(key: key);

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  bool isLoading = true;
  // Fetch active students from the "students" table with national_id.
  List<Map<String, dynamic>> activeStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  final TextEditingController searchController = TextEditingController();

  // For multi-selection of students.
  Set<String> selectedStudentIds = {};
  bool selectAll = false;

  // For force enrollment: fetch active rounds and allow selection.
  List<Map<String, dynamic>> activeRounds = [];
  String? selectedRoundIdForForce;

  @override
  void initState() {
    super.initState();
    _fetchActiveStudents();
    _fetchActiveRounds(); // Fetch rounds after fetching students potentially
    searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Fetch only students who have an active status from the "students" table.
  Future<void> _fetchActiveStudents() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('students')
          .select(
        'id, first_name, last_name, student_id, email, status, national_id',
      )
          .eq('status', 'active') // Only active students
          .order('first_name', ascending: true);

      setState(() {
        activeStudents = List<Map<String, dynamic>>.from(response);
        filteredStudents = activeStudents; // Initialize filtered list
        // Clear any previously selected student IDs.
        selectedStudentIds.clear();
        selectAll = false;
      });
    } catch (e) {
      print("Error fetching active students: $e");
      // Optionally show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching students: ${e.toString()}")),
      );
    } finally {
      // Ensure isLoading is set to false even if fetching students fails,
      // but fetching rounds might still be in progress.
      // Let _fetchActiveRounds handle the final isLoading state.
      // setState(() {
      //   isLoading = false;
      // });
    }
  }

  /// Fetch only rounds that are active (i.e. today's date is between start and end dates).
  /// UPDATED FILTERING LOGIC
  Future<void> _fetchActiveRounds() async {
    // Don't set isLoading = true here if _fetchActiveStudents already did.
    // Let the final setState handle it.
    try {
      final now = DateTime.now();
      final response = await Supabase.instance.client
          .from('rounds')
          .select('id, name, start_date, end_date')
          .order('start_date', ascending: true);

      List<Map<String, dynamic>> roundsData =
      List<Map<String, dynamic>>.from(response);

      // --- MODIFIED FILTERING LOGIC ---
      final DateTime today = DateTime(now.year, now.month, now.day); // Get today's date part only

      List<Map<String, dynamic>> active = roundsData.where((round) {
        try { // Add try-catch for robust date parsing
          DateTime startDay = DateTime.parse(round['start_date']);
          DateTime endDay = DateTime.parse(round['end_date']);
          // Normalize to date only for comparison
          startDay = DateTime(startDay.year, startDay.month, startDay.day);
          endDay = DateTime(endDay.year, endDay.month, endDay.day);

          // Check if today is on or after startDay AND on or before endDay
          return !today.isBefore(startDay) && !today.isAfter(endDay);
        } catch (e) {
          print("Error parsing dates for round ${round['id']}: $e");
          return false; // Exclude rounds with invalid dates
        }
      }).toList();
      // --- END MODIFICATION ---

      setState(() {
        activeRounds = active;
        // Reset selection if the current selection is no longer active
        if (selectedRoundIdForForce != null &&
            !activeRounds.any((r) => r['id'] == selectedRoundIdForForce)) {
          selectedRoundIdForForce = activeRounds.isNotEmpty ? activeRounds.first['id'] : null;
        } else if (activeRounds.isNotEmpty && selectedRoundIdForForce == null) {
          // Optionally, preselect the first active round if none was selected.
          selectedRoundIdForForce = activeRounds.first['id'];
        } else if (activeRounds.isEmpty) {
          // Ensure selection is cleared if no rounds are active
          selectedRoundIdForForce = null;
        }
      });
    } catch (e) {
      print("Error fetching active rounds: $e");
      // Handle error appropriately, maybe show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching rounds: ${e.toString()}")),
      );
      setState(() {
        activeRounds = []; // Ensure it's empty on error
        selectedRoundIdForForce = null;
      });
    } finally {
      // Set final loading state after both fetches are complete (or failed).
      if(mounted){ // Check if widget is still in the tree
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  /// Filter students by name, student ID, email, or national_id.
  void _filterStudents() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredStudents = activeStudents.where((student) {
        String fullName =
        "${student['first_name']} ${student['last_name']}".toLowerCase();
        String stuId = student['student_id']?.toString() ?? "";
        String email = student['email']?.toString() ?? "";
        String nationalId = student['national_id']?.toString() ?? "";
        return fullName.contains(query) ||
            stuId.contains(query) ||
            email.contains(query) ||
            nationalId.contains(query);
      }).toList();
      // Reset selection if the filtered list changes.
      selectedStudentIds.removeWhere(
              (id) => !filteredStudents.any((student) => student['id'] == id));
      selectAll = filteredStudents.isNotEmpty &&
          filteredStudents.every(
                  (student) => selectedStudentIds.contains(student['id']));
    });
  }

  /// Force redirect students to a new round by first removing them from any existing rounds.
  Future<void> _forceEnrollSelectedStudents() async {
    if (selectedRoundIdForForce == null || selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one student and a round.")),
      );
      return;
    }
    // Add loading indicator feedback
    setState(() => isLoading = true);

    try {
      for (var studentId in selectedStudentIds) {
        // Step 1: Fetch the student's current active round(s)
        // We might want to deactivate *all* existing 'in_progress' enrollments first.
        final existingEnrollmentsResponse = await Supabase.instance.client
            .from('student_rounds')
            .select('id') // Only need the ID to update
            .eq('student_id', studentId)
            .eq('status', 'in_progress'); // Find currently active enrollments

        // Step 2: Deactivate existing enrollments (set status to 'completed' or 'cancelled')
        for (var enrollment in existingEnrollmentsResponse) {
          await Supabase.instance.client
              .from('student_rounds')
              .update({'status': 'completed'}) // Or 'cancelled' depending on logic
              .eq('id', enrollment['id']);
        }

        // Step 3: Insert the student into the new round
        final newEnrollment = {
          'id': const Uuid().v4(),
          'student_id': studentId,
          'round_id': selectedRoundIdForForce,
          'status': 'in_progress', // New round is now active
        };

        await Supabase.instance.client.from('student_rounds').insert(newEnrollment);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Students have been force redirected to the new round."),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh student list and round selection after redirection
      await _fetchActiveStudents();
      await _fetchActiveRounds(); // Refetch rounds as well
      // Clear selection after successful operation
      setState(() {
        selectedStudentIds.clear();
        selectAll = false;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error during force redirection: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Ensure loading indicator stops
      if(mounted){
        setState(() => isLoading = false);
      }
    }
  }


  Widget _buildStudentTile(Map<String, dynamic> student) {
    final bool isSelected = selectedStudentIds.contains(student['id']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          activeColor: Colors.deepPurple, // Theme consistency
          onChanged: (value) {
            setState(() {
              if (value == true) {
                selectedStudentIds.add(student['id']);
              } else {
                selectedStudentIds.remove(student['id']);
              }
              // Update selectAll flag.
              selectAll = filteredStudents.isNotEmpty &&
                  filteredStudents.every(
                          (student) => selectedStudentIds.contains(student['id']));
            });
          },
        ),
        title: Text(
          "${student['first_name']} ${student['last_name']}",
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Student ID: ${student['student_id'] ?? 'N/A'}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              "National ID: ${student['national_id'] ?? 'N/A'}",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Icon(Icons.info_outline, color: Colors.deepPurple[400]), // Indicate tappable for details
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Adjust padding
        onTap: () {
          // Navigate to student details screen.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StudentDetailsScreen(studentId: student['id']),
            ),
          ).then((_) {
            // Optional: Refresh data if details might have changed status etc.
            // _fetchActiveStudents();
            // _fetchActiveRounds();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Manage Students",
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
      body: Column(
        children: [
          // Search Field.
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: "Search by Name, Student ID, Email, or National ID",
                hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear();
                    // No need to call _filterStudents here, listener does it
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder( // Consistent border style
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder( // Highlight focus
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
                ),
              ),
            ),
          ),
          // Counter and Select All option.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4), // Adjusted padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Counter.
                Text(
                  "Active Students: ${filteredStudents.length}", // Directly show count
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),

                // Select All Checkbox Row.
                Row(
                  mainAxisSize: MainAxisSize.min, // Keep row compact
                  children: [
                    Text(
                      "Select All",
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Checkbox(
                      value: selectAll,
                      activeColor: Colors.deepPurple,
                      visualDensity: VisualDensity.compact, // Make checkbox smaller
                      onChanged: (value) {
                        setState(() {
                          selectAll = value ?? false;
                          if (selectAll) {
                            // Add all *filtered* student IDs.
                            selectedStudentIds = filteredStudents
                                .map<String>((student) => student['id'])
                                .toSet();
                          } else {
                            selectedStudentIds.clear();
                          }
                        });
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
          // Dropdown for active rounds and Force Redirect button.
          // Check activeRounds AND if any students are selected to show the button
          if (activeRounds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 6, 12, 12), // Adjusted padding
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300), // Softer border
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRoundIdForForce,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[800]),
                          hint: Text("Select Round to Redirect", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])), // Add hint
                          items: activeRounds.map((round) {
                            return DropdownMenuItem<String>(
                              value: round['id'],
                              child: Text(
                                round['name'],
                                overflow: TextOverflow.ellipsis, // Handle long names
                                style: GoogleFonts.inter(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRoundIdForForce = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Only enable button if a round AND students are selected
                  ElevatedButton.icon(
                    onPressed: (selectedRoundIdForForce != null && selectedStudentIds.isNotEmpty && !isLoading) // Disable during loading
                        ? _forceEnrollSelectedStudents
                        : null, // Disable if no round or no students selected or loading
                    icon: isLoading && selectedStudentIds.isNotEmpty // Show progress only when action is attempted
                        ? Container(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.double_arrow_rounded, size: 18), // Changed icon
                    label: Text(
                      "Redirect", // Shortened label
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (selectedRoundIdForForce != null && selectedStudentIds.isNotEmpty)
                          ? Colors.orange.shade700 // Use a warning color like orange
                          : Colors.grey, // Disabled color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: (selectedRoundIdForForce != null && selectedStudentIds.isNotEmpty) ? 2 : 0, // Conditional elevation
                    ),
                  )
                ],
              ),
            ),

          // Students List.
          Expanded(
            child: isLoading && activeStudents.isEmpty // Show loading only if initial list is empty
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : filteredStudents.isEmpty
                ? Center(
              child: Text(
                searchController.text.isEmpty ? "No active students found." : "No students match your search.",
                style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            )
                : RefreshIndicator(
              onRefresh: () async { // Combine fetches for refresh
                await _fetchActiveStudents();
                await _fetchActiveRounds();
              },
              color: Colors.deepPurple, // Theme color for indicator
              child: ListView.builder(
                itemCount: filteredStudents.length,
                padding: const EdgeInsets.only(bottom: 20, left: 4, right: 4), // Add horizontal padding
                itemBuilder: (context, index) {
                  return _buildStudentTile(filteredStudents[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
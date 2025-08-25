import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'AllRoundsReportScreenAdmin.dart'; // Import the admin version

class AllStudentsReportListScreen extends StatefulWidget {
  const AllStudentsReportListScreen({Key? key}) : super(key: key);

  @override
  State<AllStudentsReportListScreen> createState() =>
      _AllStudentsReportListScreenState();
}

class _AllStudentsReportListScreenState
    extends State<AllStudentsReportListScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  String filterOption = "all"; // Options: "all", "most", "least"


  @override
  void initState() {
    super.initState();
    _fetchEnrolledStudents();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          .select('student_id, profiles!fk_student_rounds_profiles(first_name, last_name, student_id)') // Corrected join
          .eq('status', 'in_progress');

      // Create a set to store distinct student IDs
      Set<String> studentIds = {};

      // Use a list to store the processed student data
      List<Map<String, dynamic>> processedStudents = [];

      for (final record in response) {
        final studentId = record['student_id'] as String?;
        if (studentId != null && !studentIds.contains(studentId)) { // Check for duplicates using ID
          studentIds.add(studentId); // Add to the set to track

          // Fetch *all* rounds for this student
          final allRoundsResponse = await Supabase.instance.client
              .from('student_rounds')
              .select('round_id, rounds(start_date, end_date)')
              .eq('student_id', studentId);

          int totalAttendedDays = 0;
          int totalExpectedDays = 0;

          for (final roundData in allRoundsResponse) {
            final roundId = roundData['round_id'] as String?;
            if (roundId == null) continue; // Skip if round_id is null

            final round = roundData['rounds'];

            //Null Check
            if (round == null || round['start_date'] == null || round['end_date'] == null) {
              continue; // Skip this round if any critical data is missing
            }
            final startDate = DateTime.parse(round['start_date']);
            final endDate = DateTime.parse(round['end_date']);
            int expectedDays = endDate.difference(startDate).inDays + 1;

            // Excluded dates (CORRECTED LOGIC)
            final excludedDatesResponse = await Supabase.instance.client
                .from('excluded_dates')
                .select('date')
                .eq('round_id', roundId); //must for a specified round

            Set<DateTime> excludedDates = (excludedDatesResponse as List)
                .map((item) => DateTime.parse(item['date']).toLocal()) // Convert and make a set
                .toSet();

            int excludedDaysCount = 0;
            for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
              if (excludedDates.contains(DateTime(date.year, date.month, date.day))) {
                excludedDaysCount++;
              }
            }

            expectedDays -= excludedDaysCount;  // CORRECT: Subtract excluded days

            final attendanceResponse = await Supabase.instance.client
                .from('attendance')
                .select('scanned_date')
                .eq('round_id', roundId)
                .eq('student_id', studentId);
            final attendedDays = (attendanceResponse as List).length;
            // ---

            totalAttendedDays += attendedDays;
            // Correctly use adjusted expectedDays here
            totalExpectedDays += expectedDays > 0 ? expectedDays : 0; // Prevent add 0
          }

          //If all round days excluded.
          if (totalExpectedDays == 0 && totalAttendedDays == 0){
            totalExpectedDays = 1; //avoid  error, caused by 0/0, keep 1
          }

          final cumulativePercentage = totalExpectedDays > 0 ? ((totalAttendedDays / totalExpectedDays) * 100).round() : 0;

          processedStudents.add({
            'id': studentId, // Add the id here
            'first_name': record['profiles']['first_name'] ?? 'Unknown',
            'last_name': record['profiles']['last_name'] ?? '',
            'student_id': record['profiles']['student_id'] ?? 'N/A',
            'cumulativePercentage': cumulativePercentage, // Store the percentage
          });
        }
      }


      setState(() {
        students = processedStudents;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching enrolled students: $e");
      setState(() {
        isLoading = false; // Also set loading to false on error
      });
    }
  }


  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1), // Consistent shadow
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.deepPurple), // Consistent icon
        title: Text(
          "${student['first_name']} ${student['last_name']}",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Student ID: ${student['student_id']}",
              style: GoogleFonts.inter(),
            ),
            Text( // Display cumulative percentage here
              "Attendance: ${student['cumulativePercentage']}%",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500, // Make it stand out a bit
                color: _getAttendanceColor(student['cumulativePercentage']),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AllRoundsReportScreenAdmin(studentId: student['id']), // Pass the ID
            ),
          );
        },
      ),
    );
  }
  Color _getAttendanceColor(int percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    // Filter the student list based on the search query.
    final filteredStudents = students.where((student) {
      final fullName =
      "${student['first_name']} ${student['last_name']}".toLowerCase();
      final studentIdText =
      (student['student_id'] ?? '').toLowerCase();
      final query = searchQuery.toLowerCase();

      // Search filter (always applied)
      if (query.isNotEmpty &&
          !fullName.contains(query) &&
          !studentIdText.contains(query)) {
        return false;
      }
      return true; // Keep the student if it passes the search filter

    }).toList(); // Convert the result to a List


    // Sorting logic (based on filterOption) , applied *after* search filtering
    if (filterOption == "most") {
      filteredStudents.sort((a, b) => (b['cumulativePercentage'] as int).compareTo(a['cumulativePercentage'] as int));
    } else if (filterOption == "least") {
      filteredStudents.sort((a, b) => (a['cumulativePercentage'] as int).compareTo(b['cumulativePercentage'] as int));
    }
    // "all" case is already handled by the initial order (or lack thereof)

    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF), // Consistent background
      appBar: AppBar(
        title: Text(
          "All Enrolled Students",
          style: GoogleFonts.poppins( //Consistent font
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
        elevation: 8, // Consistent elevation
        shadowColor: Colors.deepPurple.withOpacity(0.4),
      ),
      body: Column( // Use a Column to arrange search bar and list
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name or ID",
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple,),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none, // Remove border
                ),
                //Clear button
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.deepPurple,),
                  onPressed: () {
                    _searchController.clear();

                  },
                )
                    : null,
              ),
              style: GoogleFonts.inter(),

            ),
          ),

          // Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  "Filter:",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: filterOption,
                  items: const [
                    DropdownMenuItem(
                      value: "all",
                      child: Text("All"),
                    ),
                    DropdownMenuItem(
                      value: "most",
                      child: Text("Most Attended"),
                    ),
                    DropdownMenuItem(
                      value: "least",
                      child: Text("Least Attended"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filterOption = value!;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple,))
                : filteredStudents.isEmpty  // Use filtered list
                ? Center(
              child: Text(
                "No students found.", // More concise message
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchEnrolledStudents,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20), // Add some padding
                itemCount: filteredStudents.length, // Use filtered list length
                itemBuilder: (context, index) {
                  return _buildStudentCard(filteredStudents[index]); // Use filtered list
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
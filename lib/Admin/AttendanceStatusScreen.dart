import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceStatusScreen extends StatefulWidget {
  final String roundId;
  final String selectedDate;

  const AttendanceStatusScreen({
    Key? key,
    required this.roundId,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<AttendanceStatusScreen> createState() =>
      _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> studentAttendance = [];

  // Variables for search and filtering.
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String filterOption = "All"; // Options: "All", "Attended", "Absent"

  @override
  void initState() {
    super.initState();
    _fetchAttendanceStatus();
  }

  /// Fetch students and their attendance status for the selected date.
  Future<void> _fetchAttendanceStatus() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Convert selectedDate from "DD-MM-YYYY" to "YYYY-MM-DD"
      List<String> dateParts = widget.selectedDate.split("-");
      String formattedDate =
          "${dateParts[2]}-${dateParts[1]}-${dateParts[0]}"; // YYYY-MM-DD

      // Fetch enrolled students for the round, including their profiles.
      final studentsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('student_id, profiles!fk_student(first_name, last_name, student_id)')
          .eq('round_id', widget.roundId);


      if (studentsResponse.isEmpty) {
        print("⚠️ No enrolled students found.");
      }

      // Fetch attendance records for the selected date, including location info.
      final attendanceResponse = await Supabase.instance.client
          .from('attendance')
          .select(
          'student_id, scanned_at, latitude, longitude, location_city, location_country')
          .eq('round_id', widget.roundId)
          .eq('scanned_date', formattedDate);

      if (attendanceResponse.isEmpty) {
        print("⚠️ No attendance records found for this date.");
      }

      // Convert attendance list to a map for quick lookup.
      Map<String, Map<String, String>> attendanceMap = {};
      for (var record in attendanceResponse) {
        String formattedTime =
        record['scanned_at'].substring(11, 16); // Extract HH:mm
        attendanceMap[record['student_id']] = {
          'time': formattedTime,
          'latitude': record['latitude']?.toString() ?? "Unknown",
          'longitude': record['longitude']?.toString() ?? "Unknown",
          'city': record['location_city'] ?? "Unknown",
          'country': record['location_country'] ?? "Unknown",
        };
      }

      // Merge attendance status with student data.
      List<Map<String, dynamic>> studentList = [];
      for (var student in studentsResponse) {
        String stuId = student['student_id'];
        bool attended = attendanceMap.containsKey(stuId);
        Map<String, String> attendanceData =
        attended ? attendanceMap[stuId]! : {};

        studentList.add({
          'first_name': student['profiles']['first_name'],
          'last_name': student['profiles']['last_name'],
          'student_id': student['profiles']['student_id'],
          'attended': attended,
          'attendance_time': attendanceData['time'] ?? "Absent",
          'latitude': attendanceData['latitude'] ?? "-",
          'longitude': attendanceData['longitude'] ?? "-",
          'city': attendanceData['city'] ?? "-",
          'country': attendanceData['country'] ?? "-",
        });
      }

      setState(() {
        studentAttendance = studentList;
      });

      print("✅ Attendance data loaded successfully.");
    } catch (e) {
      print("❌ Error fetching attendance status: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Get filtered list based on search query and filter option.
  List<Map<String, dynamic>> get filteredStudentAttendance {
    return studentAttendance.where((student) {
      // Check search query (search in first name, last name, or student_id).
      final fullName =
      "${student['first_name']} ${student['last_name']}".toLowerCase();
      final stuId = student['student_id'].toLowerCase();
      final query = searchQuery.toLowerCase();

      bool matchesSearch = query.isEmpty ||
          fullName.contains(query) ||
          stuId.contains(query);

      // Check filter option for attendance status.
      bool matchesFilter = true;
      if (filterOption == "Attended") {
        matchesFilter = student['attended'] == true;
      } else if (filterOption == "Absent") {
        matchesFilter = student['attended'] == false;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  /// Builds a student tile with styling based on attendance and training date.
  Widget _buildStudentTile(Map<String, dynamic> student) {
    // Parse the selected training date (assumed to be in dd-MM-yyyy format).
    DateTime trainingDate =
    DateFormat('dd-MM-yyyy').parse(widget.selectedDate);
    // Compare trainingDate (only date part) with today's date.
    DateTime today = DateTime.now();
    DateTime todayDate = DateTime(today.year, today.month, today.day);
    bool isFutureTraining = trainingDate.isAfter(todayDate);

    // Determine border color and status text.
    Color borderColor;
    String statusText;
    if (isFutureTraining) {
      borderColor = Colors.yellow;
      statusText = "Upcoming";
    } else {
      borderColor = student['attended'] ? Colors.green : Colors.red;
      statusText =
      student['attended'] ? "Attended at ${student['attendance_time']}" : "Absent";
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: borderColor,
          width: 2,
        ),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const Icon(Icons.person, color: Colors.deepPurple),
        title: Text(
          "${student['first_name']} ${student['last_name']}",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Student ID: ${student['student_id']}",
                style: GoogleFonts.inter()),
            Text(
              "Status: $statusText",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            // Only show detailed attendance info if training date is not in the future and the student attended.
            if (!isFutureTraining && student['attended']) ...[
              const SizedBox(height: 4),
              Text("📍 Location: ${student['city']}, ${student['country']}",
                  style: GoogleFonts.inter()),
              Text("🌍 Coordinates: ${student['latitude']}, ${student['longitude']}",
                  style: GoogleFonts.inter()),
            ]
          ],
        ),
      ),
    );
  }

  /// Builds the search field and filter dropdown.
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Search Field.
          TextField(
            controller: searchController,
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: "Search by name or student ID",
              hintStyle: GoogleFonts.inter(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  searchController.clear();
                  setState(() {
                    searchQuery = "";
                  });
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
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 10),
          // Filter Dropdown.
          Row(
            children: [
              Text(
                "Filter:",
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: filterOption,
                items: <String>["All", "Attended", "Absent"].map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: GoogleFonts.inter(fontSize: 16)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    filterOption = value!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = filteredStudentAttendance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Attendance for ${widget.selectedDate}",
          style: GoogleFonts.cairo(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
      backgroundColor: const Color(0xFFE9ECEF),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchAttendanceStatus,
        child: studentAttendance.isEmpty
            ? ListView(
          children: [
            const SizedBox(height: 100),
            Center(
              child: Text(
                "No students found for this round.",
                style: GoogleFonts.cairo(fontSize: 16),
              ),
            ),
          ],
        )
            : ListView(
          children: [
            _buildSearchAndFilter(),
            const SizedBox(height: 10),
            filteredList.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "No students match the search/filter criteria.",
                  style: GoogleFonts.cairo(fontSize: 16),
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                return _buildStudentTile(filteredList[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

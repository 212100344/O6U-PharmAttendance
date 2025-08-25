import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class RoundAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  final String studentId;

  const RoundAttendanceScreen(
      {Key? key, required this.round, required this.studentId})
      : super(key: key);

  @override
  State<RoundAttendanceScreen> createState() => _RoundAttendanceScreenState();
}

class _RoundAttendanceScreenState extends State<RoundAttendanceScreen> {
  List<DateTime> roundDates = [];
  Set<String> excludedDates = {}; // To store excluded dates
  Map<String, String> attendedRecords = {}; // Change to Map

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExcludedDates(); // Fetch excluded dates *first*
    //_generateRoundDates(); Remove calling in this method
    //_fetchAttendanceRecords();
  }

  // NEW: Fetch excluded dates
  Future<void> _fetchExcludedDates() async {
    try {
      final excludedResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', widget.round['round_id']); // Use round_id
      //print(excludedResponse); // For debugging, if needed

      // Extract and convert to a set of strings (YYYY-MM-DD)
      setState(() {
        excludedDates = (excludedResponse as List)
            .map((record) => (record['date'] as String).substring(0, 10))
            .toSet();
        _generateRoundDates(); // Call _generateRoundDates AFTER excluded dates.
        _fetchAttendanceRecords(); // Call after generating dates
      });
    } catch (e) {
      print("Error fetching excluded dates: $e");
      // Consider showing an error to the user (maybe a SnackBar)
    }
  }

  void _generateRoundDates() {
    final startDate = DateTime.parse(widget.round['rounds']['start_date']);
    final endDate = DateTime.parse(widget.round['rounds']['end_date']);
    List<DateTime> tempDates = []; // Temporary list
    for (DateTime date = startDate;
    date.isBefore(endDate.add(const Duration(days: 1)));
    date = date.add(const Duration(days: 1))) {
      // NEW: Check if the date is excluded *before* adding it.
      if (!excludedDates.contains(DateFormat('yyyy-MM-dd').format(date))) {
        tempDates.add(date); // Add to the temporary list
      }
    }
    setState(() {
      roundDates = tempDates;

    });
  }

  Future<void> _fetchAttendanceRecords() async {
    try {
      final response = await Supabase.instance.client
          .from('attendance')
          .select('scanned_date, scanned_at')
          .eq('round_id', widget.round['round_id'])
          .eq('student_id',
          widget.studentId); // Use studentId, passed by the parent

      // Convert to a Map.  Key is date, value is time.
      final Map<String, String> tempRecords = {};
      for (var record in response) {
        String scannedDate = record['scanned_date'];
        String scannedAt = record['scanned_at'];
        // Extract HH:mm from scannedAt.  This is safer.
        String time =
        scannedAt.substring(11, 16); // Get the HH:mm part, correctly
        tempRecords[scannedDate] = time;
      }
      setState(() {
        attendedRecords = tempRecords; // Update attendedRecords
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false; // Even on error, stop loading
      });
      print("Error fetching attendance records: $e");
    }
  }

  Widget _buildDateTile(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final today = DateTime.now();
    Color borderColor;
    String status;

    // No need to check for excluded dates here, they are already filtered out.

    if (attendedRecords.containsKey(dateString)) {
      // Corrected string format check
      borderColor = Colors.green;
      status = "Attended at ${attendedRecords[dateString]}"; // Show attend time
    } else if (date.isAfter(DateTime(today.year, today.month, today.day))) {
      borderColor = Colors.amber;
      status = "Upcoming";
    } else {
      borderColor = Colors.red;
      status = "Absent";
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.event,
            color: borderColor,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              DateFormat('EEE, MMM d, yyyy').format(date),
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: borderColor,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roundName = widget.round['rounds']['name'] ?? "Round Details";

    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Attendance - $roundName",
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
          : ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        itemCount: roundDates.length, // Use the filtered list
        itemBuilder: (context, index) {
          final date = roundDates[index];
          return _buildDateTile(date);
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'AttendanceStatusScreen.dart'; // Import the new screen
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase

class RoundDaysScreen extends StatefulWidget {
  final String roundName;
  final String roundId;
  final String startDate;
  final String endDate;

  const RoundDaysScreen({
    Key? key,
    required this.roundName,
    required this.roundId,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  State<RoundDaysScreen> createState() => _RoundDaysScreenState();
}

class _RoundDaysScreenState extends State<RoundDaysScreen> {
  List<String> roundDays = [];
  Set<String> excludedDates = {}; //NEW, to store excluded dates


  @override
  void initState() {
    super.initState();
    _fetchExcludedDates(); //NEW, Fetch excluded dates first!
    //_generateRoundDays(); NO, generate after fetching

  }

  //NEW, fetch method
  Future<void> _fetchExcludedDates() async {
    try {
      final excludedResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', widget.roundId); // Use round_id
      print(excludedResponse);

      // Extract and convert to a set of strings (YYYY-MM-DD)
      setState(() {
        excludedDates = (excludedResponse as List)
            .map((record) => (record['date'] as String).substring(0, 10))
            .toSet();
        _generateRoundDays();// after get data
      });

    } catch (e) {
      print("Error fetching excluded dates: $e");

    }
  }


  /// Generate a list of dates between start and end date
  void _generateRoundDays() {
    DateTime start = DateTime.parse(widget.startDate);
    DateTime end = DateTime.parse(widget.endDate);
    List<String> days = [];

    while (!start.isAfter(end)) {
      //NEW, add if statement.
      final formattedDate =
          "${start.day.toString().padLeft(2, '0')}-${start.month.toString().padLeft(2, '0')}-${start.year}";

      //NEW, Check if not excluded!
      if(!excludedDates.contains(start.toIso8601String().substring(0, 10))){
        days.add(formattedDate,);
      }
      start = start.add(const Duration(days: 1)); // Move to the next day
    }

    setState(() {
      roundDays = days;
    });
  }

  Widget _buildDayTile(String day) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
        title: Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        onTap: () {
          // Navigate to the RoundDaysScreen.
          Navigator.push(
            context,
            // NEW: Use PageRouteBuilder for custom animation
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AttendanceStatusScreen( // the correct Screen
                    roundId: widget.roundId,
                    selectedDate: day,
                  ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Add a fade transition
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.95, // slightly small
                      end: 1.0,
                    ).animate(animation), // scale up

                    child: child,
                  ),
                );

              },
              transitionDuration: const Duration(milliseconds: 250), //animation
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a gradient AppBar for consistent styling.
      appBar: AppBar(
        title: Text(
          "Round: ${widget.roundName}",
          style: GoogleFonts.cairo(
            fontSize: 18,
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
      backgroundColor: const Color(0xFFE9ECEF),
      body: roundDays.isEmpty
          ? Center(
        child: Text(
          "No days available for this round.",
          style: GoogleFonts.cairo(fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: roundDays.length,
        itemBuilder: (context, index) {
          return _buildDayTile(roundDays[index]);
        },
      ),
    );
  }
}
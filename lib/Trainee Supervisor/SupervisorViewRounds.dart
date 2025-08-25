import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SupervisorRoundStudents.dart';

class SupervisorViewRounds extends StatefulWidget {
  final String supervisorId;

  const SupervisorViewRounds({Key? key, required this.supervisorId})
      : super(key: key);

  @override
  State<SupervisorViewRounds> createState() => _SupervisorViewRoundsState();
}

class _SupervisorViewRoundsState extends State<SupervisorViewRounds> {
  bool isLoading = true;
  List<Map<String, dynamic>> rounds = [];

  @override
  void initState() {
    super.initState();
    _fetchRounds();
  }

  Future<void> _fetchRounds() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Fetch rounds where leader_id equals the supervisor's id
      final response = await Supabase.instance.client
          .from('rounds')
          .select()
          .eq('leader_id', widget.supervisorId)
          .order('start_date', ascending: true);
      setState(() {
        rounds = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Error fetching rounds: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<int> _getStudentCount(String roundId) async {
    try {
      final response = await Supabase.instance.client
          .from('student_rounds')
          .select('*')
          .eq('round_id', roundId);
      return (response as List).length;
    } catch (e) {
      print("Error fetching student count: $e");
      return 0;
    }
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    return InkWell(
      onTap: () {
        // Navigate to SupervisorRoundStudents screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupervisorRoundStudents(round: round),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: Colors.deepPurple.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                round['name'] ?? "Unnamed Round",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Duration: ${round['start_date']?.toString().substring(0, 10) ?? 'N/A'} - ${round['end_date']?.toString().substring(0, 10) ?? 'N/A'}",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Location: ${round['location'] ?? 'N/A'}",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _getStudentCount(round['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text(
                      "Total Students: ...",
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                    );
                  }
                  final count = snapshot.data ?? 0;
                  return Text(
                    "Total Students: $count",
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                  );
                },
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
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Your Rounds",
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
          ? const Center(
        child: CircularProgressIndicator(
          color: Colors.deepPurple,
        ),
      )
          : rounds.isEmpty
          ? Center(
        child: Text(
          "No rounds available.",
          style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: rounds.length,
        itemBuilder: (context, index) {
          return _buildRoundCard(rounds[index]);
        },
      ),
    );
  }
}

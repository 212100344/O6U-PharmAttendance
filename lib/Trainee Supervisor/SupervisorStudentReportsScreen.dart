// lib/Trainee Supervisor/SupervisorStudentReportsScreen.txt

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'SupervisorRoundStudentsReportScreen.dart';
import 'SupervisorQRScannerScreen.dart';  // Import the supervisor QR scanner

class SupervisorStudentReportsScreen extends StatefulWidget {
  final String supervisorId;
  const SupervisorStudentReportsScreen({Key? key, required this.supervisorId}) : super(key: key);

  @override
  State<SupervisorStudentReportsScreen> createState() => _SupervisorStudentReportsScreenState();
}

class _SupervisorStudentReportsScreenState extends State<SupervisorStudentReportsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> rounds = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSupervisorRounds();
  }

  Future<void> _fetchSupervisorRounds() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('rounds')
          .select('*')
          .eq('leader_id', widget.supervisorId)
          .order('start_date', ascending: true);
      setState(() {
        rounds = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching rounds: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          round['name'] ?? "Unnamed Round",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${round['start_date']?.toString().substring(0,10)} - ${round['end_date']?.toString().substring(0,10)}",
          style: GoogleFonts.inter(fontSize: 14),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupervisorRoundStudentsReportScreen(round: round),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Student Reports",
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
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
      ),
      body: Column( // Wrap with a Column
        children: [
          // NEW: Check Reports Button (QR Scanner)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SupervisorQRScannerScreen(), // Navigate to QR scanner
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text("Check Reports", style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Existing Rounds List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : errorMessage != null
                ? Center(child: Text(errorMessage!, style: GoogleFonts.inter(color: Colors.red)))
                : rounds.isEmpty
                ? Center(child: Text("No rounds found", style: GoogleFonts.inter()))
                : RefreshIndicator(
              onRefresh: _fetchSupervisorRounds,
              child: ListView.builder(
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
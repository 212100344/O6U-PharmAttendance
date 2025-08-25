// lib/Admin/Evaluation/ShowEvaluation.dart

import 'package:attendance_sys/Admin/Evaluation/AllStudentsReportListScreen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ManuallyEvaluatedScreen.dart';
import 'FinalEvaluationScreenAdmin.dart';
import 'AdminQRScannerScreen.dart'; // Import the QR scanner screen

class ShowEvaluation extends StatelessWidget {
  const ShowEvaluation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Evaluation Dashboard",
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                context,
                "Manually Evaluated",
                Icons.assignment_outlined,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManuallyEvaluatedScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuButton(
                context,
                "Final Evaluation",
                Icons.assignment_turned_in_outlined,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FinalEvaluationScreenAdmin(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuButton(
                context,
                "All Students Report",
                Icons.people,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllStudentsReportListScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // NEW: Check Reports Button (QR Scanner)
              _buildMenuButton(
                context,
                "Check Reports",
                Icons.qr_code_scanner, // Appropriate icon
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminQRScannerScreen(), // Navigate to QR scanner
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, String text, IconData icon, Function onPressed) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: Colors.deepPurple.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onPressed(),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
      ),
    );
  }
}
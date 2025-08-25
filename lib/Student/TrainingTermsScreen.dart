import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TrainingTermsScreen extends StatelessWidget {
  // Use a constant for the URL.  Makes it easier to change.
  static const String _googleDriveLink = "https://drive.google.com/drive/folders/1iL-oM4uwM_II9NmOdGg8PkWqlxpARamq?usp=sharing"; // Your Google Drive link

  const TrainingTermsScreen({Key? key}) : super(key: key);

  Future<void> _launchURL(BuildContext context) async { // Add BuildContext
    final Uri url = Uri.parse(_googleDriveLink);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // BEST PRACTICE:  Show a user-friendly error message.
        if (context.mounted) { // Check if the widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open the link.  Please check your internet connection and ensure you have a browser installed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Consider logging the error for debugging purposes.
        print('Could not launch $url');
      }
    } catch (e) {
      // Handle potential platform exceptions (e.g., malformed URL).
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Training Terms",
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                "You should read the training terms very carefully before starting the training process.",
                style: GoogleFonts.inter(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: Text(
                  "Google Drive",
                  style: GoogleFonts.poppins(fontSize: 18),
                ),
                onPressed: () => _launchURL(context), // Pass context
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
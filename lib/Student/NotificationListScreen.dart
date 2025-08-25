// lib/Student/NotificationListScreen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:attendance_sys/utils/notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  final String studentId;

  const NotificationListScreen({Key? key, required this.studentId})
      : super(key: key);

  @override
  State<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications =
      await notificationService.getNotifications(widget.studentId);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print("Error loading notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator( // Wrap with RefreshIndicator
        onRefresh: _loadNotifications, // Call _loadNotifications on refresh
        child: _notifications.isEmpty
            ? Center(
          child: ListView( // Use a ListView to allow for scrolling
            shrinkWrap: true, // Important for nested lists
            children: [
              Center( // Center the text
                child: Text(
                  "No notifications yet.",
                  style: GoogleFonts.inter(fontSize: 16),
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            final timestamp =
            DateTime.parse(notification['timestamp'] as String);
            final formattedDate =
            DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp);

            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification['body'] as String,
                      style: GoogleFonts.inter(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate, // Show formatted date
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
// lib/Admin/ApproveSignUps.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/notification_service.dart'; // Import
import 'package:workmanager/workmanager.dart'; // Import for background tasks
import 'package:attendance_sys/main.dart';

class ApproveSignUps extends StatefulWidget {
  const ApproveSignUps({super.key});

  @override
  State<ApproveSignUps> createState() => _ApproveSignUpsState();
}

class _ApproveSignUpsState extends State<ApproveSignUps> {
  List<Map<String, dynamic>> allPendingStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  Set<String> selectedStudentIds = {};
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingSignUps();
    searchController.addListener(_filterStudents);
  }
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingSignUps() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, first_name, last_name, email, student_id, national_id')
          .eq('status', 'inactive')
          .order('created_at', ascending: true);

      setState(() {
        allPendingStudents = List<Map<String, dynamic>>.from(response);
        filteredStudents = allPendingStudents;
        selectedStudentIds.clear();
        selectAll = false;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error fetching sign-ups: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterStudents() {
    String query = searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        filteredStudents = allPendingStudents;
      } else {
        filteredStudents = allPendingStudents
            .where((student) =>
            student['student_id'].toString().contains(query))
            .toList();
      }

      selectedStudentIds.removeWhere(
              (id) => !filteredStudents.any((student) => student['id'] == id));
      selectAll = filteredStudents.isNotEmpty &&
          filteredStudents.every(
                  (student) => selectedStudentIds.contains(student['id']));
    });
  }

  Future<void> _approveStudent(Map<String, dynamic> student) async {
    final studentId = student['id'];
    // --- Get the email here, *before* any database operations ---
    final studentEmail = student['email'] as String;


    try {
      // 1. Update the 'profiles' table (status to 'active').
      final profilesUpdateResult = await Supabase.instance.client
          .from('profiles')
          .update({'status': 'active'})
          .eq('id', studentId)
          .select(); // Important to get the result back

      if (profilesUpdateResult == null || profilesUpdateResult.isEmpty) {
        // Throw a *specific* exception if the update fails.
        throw Exception(
            'Failed to update profiles table.  No data returned.');
      }

      // 2. Prepare the data for the 'students' table.
      final studentData = {
        'id': studentId,  //  Use UUID.
        'first_name': student['first_name'],
        'last_name': student['last_name'],
        'email': studentEmail, // Use email.
        'student_id': student['student_id'],
        'national_id': student['national_id'],
        'status': 'active', // Set status to active.
      };

      // 3. Upsert into the 'students' table.
      final studentUpdateResult = await Supabase.instance.client
          .from('students')
          .upsert(studentData)
          .select();  //  to get the result

      //check the update result
      if (studentUpdateResult == null) {
        // Throw exception.
        throw Exception(
            'Failed to update students table. No data returned.');
      }
      // --- Pass the email to WorkManager ---
      await Workmanager().registerOneOffTask(
        checkStatusTaskKey,
        "checkStatus",
        inputData: {'email': studentEmail}, // PASS THE EMAIL HERE
      );

    } catch (e) {
      print("Error approving student: $e");
      // Show specific error to the user.
      Fluttertoast.showToast(
        msg: 'Error approving student: $e', // Show the actual error
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> _rejectStudent(String userId) async {

    try{

      bool notificationSent = await notificationService.hasNotificationBeenSent(userId);
      if (notificationSent) {
        await notificationService.removeNotificationFlag(userId);

      }

      await Supabase.instance.client.from('profiles').delete().eq('id', userId);

      await Supabase.instance.client.from('students')
          .delete()
          .eq('id', userId);

      Fluttertoast.showToast(
        msg: "Student sign-up request rejected!",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      _fetchPendingSignUps();

    }catch(e){

      print("error: $e");
      Fluttertoast.showToast(msg: " error with operations , Try Later!",

        toastLength: Toast.LENGTH_SHORT,

        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

  }
  Future<void> _approveSelectedStudents() async {
    if (selectedStudentIds.isEmpty) {
      Fluttertoast.showToast(
          msg: "No students selected.", backgroundColor: Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      for (final studentId in selectedStudentIds) {
        final studentData = allPendingStudents.firstWhere(
              (student) => student['id'] == studentId,
          orElse: () => {}, // Return empty map if not found.
        );

        if (studentData.isNotEmpty) {
          await _approveStudent(studentData);

        }
      }

      Fluttertoast.showToast(
        msg: "Selected students approved successfully!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error approving students: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
      _fetchPendingSignUps();
    }
  }


  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isSelected = selectedStudentIds.contains(student['id']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
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
          activeColor: Colors.deepPurple,
        ),
        title: Text(
          "${student['first_name']} ${student['last_name']}",
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800]),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Email: ${student['email']}",
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              "Student ID: ${student['student_id']}",
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
              onPressed: () => _rejectStudent(student['id']),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Approve Student Sign Ups",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search by Student ID",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Select All", style: GoogleFonts.inter()),
                      Checkbox(
                        value: selectAll,
                        onChanged: (bool? value) {
                          setState(() {
                            selectAll = value ?? false;
                            if (selectAll) {
                              selectedStudentIds = filteredStudents
                                  .map<String>((student) => student['id'])
                                  .toSet();
                            } else {
                              selectedStudentIds.clear();
                            }
                          });
                        },
                        activeColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: (!isLoading && selectedStudentIds.isNotEmpty)
                        ? _approveSelectedStudents
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Approve Selected", style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ?  Center(child: CircularProgressIndicator( color: Colors.deepPurple),)
                  : filteredStudents.isEmpty
                  ? Center(
                child: Text(
                  "No pending sign-ups",
                  style: GoogleFonts.inter(
                      fontSize: 16, color: Colors.grey[600]),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  return _buildStudentCard(filteredStudents[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
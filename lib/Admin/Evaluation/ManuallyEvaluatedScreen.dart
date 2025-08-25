import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManuallyEvaluatedScreen extends StatefulWidget {
  const ManuallyEvaluatedScreen({Key? key}) : super(key: key);

  @override
  State<ManuallyEvaluatedScreen> createState() =>
      _ManuallyEvaluatedScreenState();
}

class _ManuallyEvaluatedScreenState extends State<ManuallyEvaluatedScreen> {
  List<StudentEvaluation> studentEvaluations = [];
  List<StudentEvaluation> filteredEvaluations = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEvaluations();
    _searchController.addListener(_filterEvaluations);
  }

  void _filterEvaluations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredEvaluations = studentEvaluations.where((student) {
        final fullName =
        '${student.firstName} ${student.lastName}'.toLowerCase();
        final studentId = student.displayStudentId.toLowerCase();
        return fullName.contains(query) || studentId.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchEvaluations() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('evaluations')
          .select(
          'student_id, comments, profiles!inner(first_name, last_name, student_id)');

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var eval in response) {
        final studentId = eval['student_id'] as String;
        grouped.putIfAbsent(studentId, () => []).add(eval);
      }

      studentEvaluations = grouped.entries.map((entry) {
        final firstEval = entry.value.first;
        return StudentEvaluation(
          studentId: entry.key,
          displayStudentId:
          firstEval['profiles']['student_id']?.toString() ?? 'N/A',
          firstName: firstEval['profiles']['first_name'] ?? 'Unknown',
          lastName: firstEval['profiles']['last_name'] ?? 'Unknown',
          evaluations: entry.value,
        );
      }).toList();

      setState(() {
        filteredEvaluations = studentEvaluations;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _showAllEvaluations(BuildContext context, StudentEvaluation studentEval) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${studentEval.firstName} ${studentEval.lastName}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            Text(
              "ID: ${studentEval.displayStudentId}",
              style:
              GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: studentEval.evaluations.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey[300]),
            itemBuilder: (context, index) {
              final evaluation = studentEval.evaluations[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "• ${evaluation['comments'] ?? 'No comments'}",
                  style: GoogleFonts.inter(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Manual Evaluations",
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Search by name or student ID...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                  prefixIcon:
                  Icon(Icons.search, color: Colors.deepPurple[800]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.deepPurple[800]!, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                ),
                style: GoogleFonts.inter(color: Colors.grey[800]),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
                ),
              ),
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                    color: Colors.deepPurple),
              )
                  : filteredEvaluations.isEmpty
                  ? Center(
                child: Text(
                  "No students found",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.separated(
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredEvaluations.length,
                separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final studentEval = filteredEvaluations[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    shadowColor:
                    Colors.deepPurple.withOpacity(0.1),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          _showAllEvaluations(context, studentEval),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple
                                        .withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.deepPurple[800],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${studentEval.firstName} ${studentEval.lastName}",
                                        style: GoogleFonts.poppins(
                                          fontWeight:
                                          FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Text(
                                        "ID: ${studentEval.displayStudentId}",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    "${studentEval.evaluations.length} ${studentEval.evaluations.length == 1 ? 'Evaluation' : 'Evaluations'}",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: Colors.deepPurple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...studentEval.evaluations
                                .take(2)
                                .map((evaluation) => Padding(
                              padding:
                              const EdgeInsets.symmetric(
                                  vertical: 4),
                              child: Text(
                                "• ${evaluation['comments'] ?? 'No comments'}",
                                style: GoogleFonts.inter(
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            )),
                            if (studentEval.evaluations.length > 2)
                              Padding(
                                padding:
                                const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Tap to view all ${studentEval.evaluations.length} evaluations",
                                  style: GoogleFonts.inter(
                                    color: Colors.deepPurple,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentEvaluation {
  final String studentId;
  final String displayStudentId;
  final String firstName;
  final String lastName;
  final List<Map<String, dynamic>> evaluations;

  StudentEvaluation({
    required this.studentId,
    required this.displayStudentId,
    required this.firstName,
    required this.lastName,
    required this.evaluations,
  });
}

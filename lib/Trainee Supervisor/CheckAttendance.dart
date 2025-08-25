// lib/Trainee Supervisor/CheckAttendance.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

/// --------------------------------------------------------
/// CheckAttendance Screen
/// --------------------------------------------------------
class CheckAttendance extends StatefulWidget {
  final String supervisorId;

  const CheckAttendance({Key? key, required this.supervisorId})
      : super(key: key);

  @override
  State<CheckAttendance> createState() => _CheckAttendanceState();
}

class _CheckAttendanceState extends State<CheckAttendance> {
  List<Map<String, dynamic>> rounds = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRounds();
  }

  Future<void> _fetchRounds() async {
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
        errorMessage = "❌ Error fetching rounds: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _navigateToRoundAttendance(Map<String, dynamic> round) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RoundAttendanceScreen(round: round),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const ShimmerLoadingList();
    }
    if (errorMessage != null) {
      return ErrorState(message: errorMessage!, onRetry: _fetchRounds);
    }
    if (rounds.isEmpty) {
      return EmptyState(onRefresh: _fetchRounds);
    }
    return RefreshIndicator(
      onRefresh: _fetchRounds,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: rounds.length,
        itemBuilder: (context, index) => _RoundCard(
          round: rounds[index],
          onTap: () => _navigateToRoundAttendance(rounds[index]),
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
          "Attendance Overview",
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
      body: _buildBody(),
    );
  }
}

/// --------------------------------------------------------
/// _RoundCard Widget
/// --------------------------------------------------------
class _RoundCard extends StatelessWidget {
  final Map<String, dynamic> round;
  final VoidCallback onTap;

  const _RoundCard({required this.round, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_month, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    round['name'] ?? "Unnamed Round",
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${dateFormat.format(DateTime.parse(round['start_date']))} - ${dateFormat.format(DateTime.parse(round['end_date']))}",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// --------------------------------------------------------
/// RoundAttendanceScreen
/// --------------------------------------------------------
class RoundAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> round;
  const RoundAttendanceScreen({Key? key, required this.round}) : super(key: key);

  @override
  State<RoundAttendanceScreen> createState() => _RoundAttendanceScreenState();
}

class _RoundAttendanceScreenState extends State<RoundAttendanceScreen> {
  List<DateTime> roundDates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateRoundDates();
    setState(() => isLoading = false);
  }

  void _generateRoundDates() {
    final startDate = DateTime.parse(widget.round['start_date']);
    final endDate = DateTime.parse(widget.round['end_date']);
    for (DateTime date = startDate;
    date.isBefore(endDate.add(const Duration(days: 1)));
    date = date.add(const Duration(days: 1))) {
      roundDates.add(date);
    }
  }

  void _navigateToAttendanceDetails(String date) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AttendanceDetailsScreen(date: date, roundId: widget.round['id']),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roundName = widget.round['name'] ?? "Round Details";
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
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: roundDates.length,
        itemBuilder: (context, index) => _DateCard(
          date: roundDates[index],
          onTap: () => _navigateToAttendanceDetails(
              DateFormat('yyyy-MM-dd').format(roundDates[index])),
        ),
      ),
    );
  }
}

/// --------------------------------------------------------
/// _DateCard Widget
/// --------------------------------------------------------
class _DateCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayFormat = DateFormat('EEEE');
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayFormat.format(date),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  dateFormat.format(date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward, size: 18, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// --------------------------------------------------------
/// AttendanceDetailsScreen
/// --------------------------------------------------------
class AttendanceDetailsScreen extends StatefulWidget {
  final String date;
  final String roundId;

  const AttendanceDetailsScreen({Key? key, required this.date, required this.roundId})
      : super(key: key);

  @override
  State<AttendanceDetailsScreen> createState() => _AttendanceDetailsScreenState();
}

class _AttendanceDetailsScreenState extends State<AttendanceDetailsScreen> {
  List<Map<String, dynamic>> students = [];
  Set<String> attendedStudents = {};
  bool isLoading = true;

  String searchQuery = '';
  String filterStatus = 'all'; // Options: 'all', 'attended', 'absent'

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() => isLoading = true);
    try {
      final enrolledResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('student_id, profiles!fk_student_rounds_profiles(first_name, last_name, student_id)') // Corrected join
          .eq('round_id', widget.roundId);

      final attendanceResponse = await Supabase.instance.client
          .from('attendance')
          .select('student_id')
          .eq('round_id', widget.roundId)
          .eq('scanned_date', widget.date);
      // print response to help
      print(attendanceResponse);
      setState(() {
        students = List<Map<String, dynamic>>.from(enrolledResponse);
        attendedStudents =
            attendanceResponse.map((e) => e['student_id'] as String).toSet();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Counters for the header.
    final int totalEnrolled = students.length;
    final int totalAttended = attendedStudents.length;
    final int totalAbsent = totalEnrolled - totalAttended;

    // Filter the student list based on the search query and filterStatus.
    final filteredStudents = students.where((student) {
      final fullName =
      "${student['profiles']['first_name']} ${student['profiles']['last_name']}".toLowerCase();
      final studentIdText =
      (student['profiles']['student_id'] ?? '').toLowerCase();
      final query = searchQuery.toLowerCase();

      if (query.isNotEmpty &&
          !fullName.contains(query) &&
          !studentIdText.contains(query)) {
        return false;
      }

      final isAttended = attendedStudents.contains(student['student_id']);
      if (filterStatus == 'attended' && !isAttended) return false;
      if (filterStatus == 'absent' && isAttended) return false;

      return true;
    }).toList(); // Convert the result to a List


    // Sorting logic (based on filterOption) , applied *after* search filtering
    if (filterStatus == "all") {
      filteredStudents.sort((a, b) {
        final aAttended = attendedStudents.contains(a['student_id']) ? 0 : 1;
        final bAttended = attendedStudents.contains(b['student_id']) ? 0 : 1;
        return aAttended.compareTo(bAttended);
      });
    }
    // "all" case is already handled by the initial order (or lack thereof)

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.date)),
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A1B9A),
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
          : Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search by name or student ID",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          // Filter dropdown.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  "Filter:",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: filterStatus,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text("All"),
                    ),
                    DropdownMenuItem(
                      value: 'attended',
                      child: Text("Attended"),
                    ),
                    DropdownMenuItem(
                      value: 'absent',
                      child: Text("Absent"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        filterStatus = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Counters Header.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CounterTile(
                  label: "Attended",
                  count: totalAttended,
                  color: Colors.green,
                ),
                _CounterTile(
                  label: "Absent",
                  count: totalAbsent,
                  color: Colors.red,
                ),
                _CounterTile(
                  label: "Total",
                  count: totalEnrolled,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // List of student cards.
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAttendanceData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: filteredStudents.length, // Use filtered list length
                itemBuilder: (context, index) => _StudentAttendanceCard(
                  student: filteredStudents[index], // Use filtered list
                  isPresent: attendedStudents
                      .contains(filteredStudents[index]['student_id']),// Use filtered list
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------
/// _StudentAttendanceCard Widget
/// --------------------------------------------------------
class _StudentAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isPresent;

  const _StudentAttendanceCard(
      {required this.student, required this.isPresent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName =
        "${student['profiles']['first_name']} ${student['profiles']['last_name']}";
    final displayStudentId = student['profiles']['student_id'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              fullName.substring(0, 1),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "ID: $displayStudentId",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPresent
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent ? Icons.check : Icons.close,
                  size: 16,
                  color: isPresent ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isPresent ? "Present" : "Absent",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isPresent ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------
/// _CounterTile Widget
/// --------------------------------------------------------
class _CounterTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CounterTile({
    Key? key,
    required this.label,
    required this.count,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          "$count",
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// --------------------------------------------------------
/// Utility Widgets: ShimmerLoadingList, ShimmerLoading, ErrorState, EmptyState
/// --------------------------------------------------------
class ShimmerLoadingList extends StatelessWidget {
  const ShimmerLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const ShimmerLoading(),
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      height: 24,
      width: double.infinity,
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              "No rounds found",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Start by creating a new round",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }
}
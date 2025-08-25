// lib/Admin/AdminManageRounds.dart (MODIFIED)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'RoundDaysScreen.dart';
import 'package:intl/intl.dart'; // Import intl package

class AdminManageRounds extends StatefulWidget {
  const AdminManageRounds({Key? key}) : super(key: key);

  @override
  State<AdminManageRounds> createState() => _AdminManageRoundsState();
}

class _AdminManageRoundsState extends State<AdminManageRounds> {
  final TextEditingController roundNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  bool isLoading = false;
  List<Map<String, dynamic>> rounds = [];
  List<Map<String, dynamic>> supervisors = [];
  String? selectedSupervisorId;
  DateTime? startDate;
  DateTime? endDate;
  // NEW: List to store excluded dates
  List<DateTime> excludedDates = [];

  @override
  void initState() {
    super.initState();
    _fetchRounds();
    _fetchSupervisors();
  }

  Future<void> _fetchRounds() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await Supabase.instance.client
          .from('rounds')
          .select()
          .order('created_at', ascending: true);

      //NEW
      // Fetch excluded dates for each round
      for (var round in response) {
        final excludedDatesResponse = await Supabase.instance.client
            .from('excluded_dates')
            .select('date')
            .eq('round_id', round['id']);

        // Convert the response to a List<DateTime>
        List<DateTime> dates = (excludedDatesResponse as List)
            .map((item) => DateTime.parse(item['date']))
            .toList();

        round['excluded_dates'] = dates; // Store directly in the round data
      }
      setState(() {
        rounds = List<Map<String, dynamic>>.from(response);

      });
    } catch (e) {
      print('Error fetching rounds: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchSupervisors() async {
    try {
      // Query supervisors without the join
      final supervisorsResponse = await Supabase.instance.client
          .from('supervisors')
          .select('id, first_name, last_name, training_center_id')
          .order('first_name', ascending: true);
      // Query training centers separately
      final trainingCentersResponse = await Supabase.instance.client
          .from('training_centers')
          .select('id, name');
      List<Map<String, dynamic>> supervisorsList =
      List<Map<String, dynamic>>.from(supervisorsResponse);
      List<Map<String, dynamic>> trainingCentersList =
      List<Map<String, dynamic>>.from(trainingCentersResponse);
      // Build a map from training center id to its name
      Map<String, String> trainingCenterMap = {};
      for (var tc in trainingCentersList) {
        trainingCenterMap[tc['id']] = tc['name'];
      }
      // Append training center name to each supervisor
      supervisorsList = supervisorsList.map((sup) {
        sup['training_center_name'] =
            trainingCenterMap[sup['training_center_id']] ?? "";
        return sup;
      }).toList();
      setState(() {
        supervisors = supervisorsList;
      });
    } catch (e) {
      print('Error fetching supervisors: $e');
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: startDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6A1B9A),
              onPrimary: Colors.white,
              onSurface: Colors.deepPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        startDate = pickedDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: endDate ?? (startDate ?? now).add(const Duration(days: 1)),
      firstDate: startDate ?? now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6A1B9A),
              onPrimary: Colors.white,
              onSurface: Colors.deepPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        endDate = pickedDate;
      });
    }
  }
  Future<void> _pickExcludedDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000), // Or appropriate start date
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6A1B9A), // Primary color for your theme
              onPrimary: Colors.white, // Color for selected date
              onSurface: Colors.black, // Color for text/icons
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && !excludedDates.contains(pickedDate)) {
      setState(() {
        excludedDates.add(pickedDate);
        // Sort the list after adding new date
        excludedDates.sort((a, b) => a.compareTo(b));
      });
    }
  }
  // Helper function to format and display a single date
  Widget _buildDateChip(DateTime date, VoidCallback onRemove) {
    return Chip(
      label: Text(DateFormat('yyyy-MM-dd').format(date)),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.cancel),
      deleteIconColor: Colors.red[400],
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
  void _removeExcludedDate(DateTime dateToRemove) {
    setState(() {
      excludedDates.remove(dateToRemove);
    });
  }

  /// Create a new round.
  Future<void> _createRound() async {
    final roundName = roundNameController.text.trim();
    final location = locationController.text.trim();

    if (roundName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Round name cannot be empty")),
      );
      return;
    }
    if (selectedSupervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a round leader")),
      );
      return;
    }
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end dates")),
      );
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text("Please enter the training center location")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });
    try {
      final newRound = {
        'id': Uuid().v4(),
        'name': roundName,
        'leader_id': selectedSupervisorId,
        'start_date': startDate!.toIso8601String(),
        'end_date': endDate!.toIso8601String(),
        'location': location,
      };
      // Insert the new round into the rounds table.
      final roundData = await Supabase.instance.client.from('rounds').insert(newRound).select();

      // Insert excluded dates
      if (excludedDates.isNotEmpty && roundData.isNotEmpty) {
        final roundId = roundData[0]['id']; // Get the ID of the newly created round
        final excludedDatesData = excludedDates.map((date) => {
          'round_id': roundId,
          'date': date.toIso8601String(), // Store in ISO8601 format
        }).toList();
        await Supabase.instance.client.from('excluded_dates').insert(excludedDatesData).select();
      }
      roundNameController.clear();
      locationController.clear();
      setState(() {
        selectedSupervisorId = null;
        startDate = null;
        endDate = null;
        excludedDates.clear(); // NEW: Clear excluded dates
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Round created successfully!")),
      );
      _fetchRounds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating round: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Update an existing round.
  Future<void> _updateRound(String roundId) async {
    final roundName = roundNameController.text.trim();
    final location = locationController.text.trim();

    // Validation checks
    if (roundName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Round name cannot be empty")),
      );
      return;
    }
    if (selectedSupervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a round leader")),
      );
      return;
    }
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end dates")),
      );
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text("Please enter the training center location")),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      // Update round details
      final updatedRound = {
        'name': roundName,
        'leader_id': selectedSupervisorId,
        'start_date': startDate!.toIso8601String(),
        'end_date': endDate!.toIso8601String(),
        'location': location,
      };

      await Supabase.instance.client
          .from('rounds')
          .update(updatedRound)
          .eq('id', roundId)
          .select();

      // --- Manage Excluded Dates ---
      // 1. Fetch existing excluded dates for this round
      final existingExcludedDatesResponse = await Supabase.instance.client
          .from('excluded_dates')
          .select('date')
          .eq('round_id', roundId);

      // Convert existing dates to a List<DateTime> for easier comparison
      List<DateTime> existingDates = (existingExcludedDatesResponse as List)
          .map((item) => DateTime.parse(item['date'] as String))
          .toList();

      // 2. Find dates to add (present in excludedDates but not in existingDates)
      List<DateTime> datesToAdd = excludedDates.where((date) => !existingDates.contains(date)).toList();

      // 3. Find dates to remove (present in existingDates but not in excludedDates)
      List<DateTime> datesToRemove = existingDates.where((date) => !excludedDates.contains(date)).toList();

      // 4. Insert new dates
      if (datesToAdd.isNotEmpty) {
        final newDatesData = datesToAdd.map((date) => {
          'round_id': roundId,
          'date': date.toIso8601String(), // Store in ISO8601 format
        }).toList();
        await Supabase.instance.client.from('excluded_dates').insert(newDatesData).select();
      }

      // 5. Delete removed dates
      if (datesToRemove.isNotEmpty) {
        for (final date in datesToRemove) {
          await Supabase.instance.client
              .from('excluded_dates')
              .delete()
              .eq('round_id', roundId)
              .eq('date', date.toIso8601String()); // Use toIso8601String()
        }
      }


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Round updated successfully!")),
      );
      Navigator.of(context).pop(); // Close the edit dialog
      _fetchRounds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating round: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Show a dialog for editing an existing round.
  void _showEditRoundDialog(Map<String, dynamic> round) {
    // Pre-fill the controllers and state with the selected round's data.
    roundNameController.text = round['name'] ?? "";
    locationController.text = round['location'] ?? "";
    selectedSupervisorId = round['leader_id'];
    startDate = DateTime.parse(round['start_date']);
    endDate = DateTime.parse(round['end_date']);
    //NEW
    excludedDates = List<DateTime>.from(round['excluded_dates'] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Edit Round",
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter dialogSetState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Round Name
                      TextField(
                        controller: roundNameController,
                        decoration: InputDecoration(
                          labelText: "Round Name",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: GoogleFonts.inter(),
                      ),
                      const SizedBox(height: 12),
                      // Supervisor Dropdown
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Select Round Leader",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSupervisorId,
                            hint: const Text("Choose Supervisor"),
                            isExpanded: true,
                            items: supervisors.map((supervisor) {
                              final supervisorId = supervisor['id'];
                              final firstName = supervisor['first_name'];
                              final lastName = supervisor['last_name'];
                              final trainingCenterName =
                              supervisor['training_center_name'] as String;
                              final displayText =
                                  "$firstName $lastName - $trainingCenterName";
                              return DropdownMenuItem<String>(
                                value: supervisorId,
                                child: Text(displayText, style: GoogleFonts.inter()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSupervisorId = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Start Date Picker
                      OutlinedButton(
                        onPressed: _pickStartDate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6A1B9A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          startDate == null
                              ? "Select Start Date"
                              : "Start: ${startDate!.toLocal().toString().substring(0, 10)}",
                          style: GoogleFonts.inter(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // End Date Picker
                      OutlinedButton(
                        onPressed: _pickEndDate,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6A1B9A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          endDate == null
                              ? "Select End Date"
                              : "End: ${endDate!.toLocal().toString().substring(0, 10)}",
                          style: GoogleFonts.inter(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Location
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: "Training Center Location",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: GoogleFonts.inter(),
                      ),
                      const SizedBox(height: 12),
                      // NEW: Excluded Dates Section
                      Text("Excluded Dates:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Wrap(
                        spacing: 8.0, // Space between chips
                        runSpacing: 4.0, // Space between lines
                        children: excludedDates.map((date) {
                          return _buildDateChip(date, () {
                            dialogSetState(() { // Use dialogSetState
                              excludedDates.remove(date);
                            });
                          });
                        }).toList(),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000), // Or appropriate start date
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF6A1B9A), // Header background color
                                    onPrimary: Colors.white, // Header text color
                                    onSurface: Colors.black, // Body text color
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.deepPurple, // button text color
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null && !excludedDates.contains(pickedDate)) {
                            dialogSetState(() {
                              excludedDates.add(pickedDate);
                              excludedDates.sort((a,b) => a.compareTo(b)); //keep it sorted
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: Text("Add Excluded Date", style: GoogleFonts.poppins(),),
                      ),
                    ],
                  );
                }
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                // Call update with the round id.
                _updateRound(round['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("Update", style: GoogleFonts.poppins()),
            )
          ],
        );
      },
    );
  }

  Future<void> deleteRound(String roundId) async {
    try {
      // ✅ Step 1: Delete all attendance records linked to this round
      await Supabase.instance.client
          .from('attendance')
          .delete()
          .eq('round_id', roundId);

      // ✅ Step 2: Delete the round
      await Supabase.instance.client
          .from('rounds')
          .delete()
          .eq('id', roundId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Round deleted successfully.", style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
      _fetchRounds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting round: $e", style: GoogleFonts.inter())),
      );
    }
  }

  Widget _buildRoundCard(Map<String, dynamic> round) {
    String leaderName = "Unknown";
    if (round['leader_id'] != null && supervisors.isNotEmpty) {
      final leader = supervisors.firstWhere(
            (sup) => sup['id'] == round['leader_id'],
        orElse: () => {},
      );
      if (leader.isNotEmpty) {
        leaderName = "${leader['first_name']} ${leader['last_name']}";
      }
    }
    // NEW: Format excluded dates for display
    String excludedDatesString = "None";
    if (round['excluded_dates'] != null && round['excluded_dates'].isNotEmpty) {
      excludedDatesString = (round['excluded_dates'] as List<DateTime>)
          .map((date) => DateFormat('yyyy-MM-dd').format(date))
          .join(', ');
    }
    return InkWell(
      onTap: () {
        // Navigate to the RoundDaysScreen.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoundDaysScreen(
              roundId: round['id'],
              roundName: round['name'] ?? "Unnamed Round",
              startDate: round['start_date'],
              endDate: round['end_date'],
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: Colors.deepPurple.withOpacity(0.1),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          title: Text(
            round['name'] ?? "Unnamed Round",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            "Leader: $leaderName\nDuration: ${round['start_date']?.toString().substring(0, 10) ?? 'N/A'} to ${round['end_date']?.toString().substring(0, 10) ?? 'N/A'}\nLocation: ${round['location'] ?? 'N/A'}\nExcluded Dates: $excludedDatesString", // Display excluded dates

            style: GoogleFonts.inter(),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  _showEditRoundDialog(round);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  deleteRound(round['id']);
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
          "Manage Rounds",
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
      // Wrap the entire scrollable content with RefreshIndicator.
      body: RefreshIndicator(
        onRefresh: _fetchRounds,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Create New Round",
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 20),
              // Round Name Input
              TextField(
                controller: roundNameController,
                decoration: InputDecoration(
                  labelText: "Round Name",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 20),
              // Dropdown for selecting Round Leader with Training Center name appended
              InputDecorator(
                decoration: InputDecoration(
                  labelText: "Select Round Leader",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSupervisorId,
                    hint: const Text("Choose Supervisor"),
                    isExpanded: true,
                    items: supervisors.map((supervisor) {
                      final supervisorId = supervisor['id'];
                      final firstName = supervisor['first_name'];
                      final lastName = supervisor['last_name'];
                      final trainingCenterName =
                      supervisor['training_center_name'] as String;
                      final displayText =
                          "$firstName $lastName - $trainingCenterName";
                      return DropdownMenuItem<String>(
                        value: supervisorId,
                        child: Text(displayText, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSupervisorId = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Date Pickers for Start Date and End Date
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStartDate,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6A1B9A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        startDate == null
                            ? "Select Start Date"
                            : "Start: ${startDate!.toLocal().toString().substring(0, 10)}",
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEndDate,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6A1B9A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        endDate == null
                            ? "Select End Date"
                            : "End: ${endDate!.toLocal().toString().substring(0, 10)}",
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // NEW: Section for Excluded Dates
              Text("Excluded Dates:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8.0, // Space between chips
                runSpacing: 4.0, // Space between lines
                children: excludedDates.map((date) => _buildDateChip(date, () {
                  setState(() {
                    excludedDates.remove(date);
                  });
                })).toList(),
              ),
              ElevatedButton.icon(
                onPressed:_pickExcludedDate,
                icon: const Icon(Icons.add),
                label: Text("Add Excluded Date", style: GoogleFonts.poppins(),),

              ),
              const SizedBox(height: 20),
              // Input for Training Center Location
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: "Training Center Location",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _createRound,
                icon: const Icon(Icons.add),
                label: Text("Create Round", style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text(
                "Existing Rounds",
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator(color: Colors.deepPurple)
                  : rounds.isEmpty
                  ? Text("No rounds created yet.", style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]))
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rounds.length,
                itemBuilder: (context, index) {
                  return _buildRoundCard(rounds[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
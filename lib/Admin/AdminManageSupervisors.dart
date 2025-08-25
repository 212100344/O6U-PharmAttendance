import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManageSupervisors extends StatefulWidget {
  const AdminManageSupervisors({Key? key}) : super(key: key);

  @override
  State<AdminManageSupervisors> createState() => _AdminManageSupervisorsState();
}

class _AdminManageSupervisorsState extends State<AdminManageSupervisors> {
  List<Map<String, dynamic>> _supervisors = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSupervisors();
  }

  Future<void> _fetchSupervisors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supResponse = await Supabase.instance.client
          .from('supervisors')
          .select('id, first_name, last_name, email, training_center_id, training_centers(name)');

      if (supResponse is! List || supResponse.isEmpty) {
        throw Exception('No supervisors found or invalid data format');
      }

      final profResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, status');

      final profilesMap = <String, String>{};
      if (profResponse is List) {
        for (final profile in profResponse) {
          final id = profile['id']?.toString();
          final status = profile['status']?.toString();
          if (id != null && status != null) {
            profilesMap[id] = status;
          }
        }
      }

      final mergedData = (supResponse as List<dynamic>).map<Map<String, dynamic>>((sup) {
        final supervisor = Map<String, dynamic>.from(sup as Map);
        final supervisorId = supervisor['id']?.toString();

        if (supervisorId != null && profilesMap.containsKey(supervisorId)) {
          supervisor['profiles'] = {'status': profilesMap[supervisorId]};
        } else {
          supervisor['profiles'] = {'status': 'unknown'};
        }

        return supervisor;
      }).toList();

      setState(() {
        _supervisors = mergedData;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch supervisors: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _deleteSupervisor(String supervisorId) async {
    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
            "Are you sure you want to permanently delete this supervisor and their associated data? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return; // Exit if not confirmed
    }

    setState(() => _isLoading = true); // Start loading

    try {
      // 1. Fetch the supervisor's training_center_id *before* deleting.
      final supervisorResponse = await Supabase.instance.client
          .from('supervisors')
          .select('training_center_id')
          .eq('id', supervisorId)
          .maybeSingle();  // Use maybeSingle

      String? trainingCenterId = supervisorResponse?['training_center_id'];

      // 2. Delete from the 'supervisors' table.
      await Supabase.instance.client
          .from('supervisors')
          .delete()
          .eq('id', supervisorId);

      // 3. Check if the training center is used by other supervisors.
      if (trainingCenterId != null) {
        final otherSupervisorsResponse = await Supabase.instance.client
            .from('supervisors')
            .select('id')
            .eq('training_center_id', trainingCenterId);

        if (otherSupervisorsResponse.isEmpty) {
          // If no other supervisors use this center, delete it.
          await Supabase.instance.client
              .from('training_centers')
              .delete()
              .eq('id', trainingCenterId);
        }
      }

      // 4. Delete from the 'profiles' table.  Do this *last*.
      await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', supervisorId);

      // Remove from local list.
      setState(() {
        _supervisors.removeWhere((sup) => sup['id'] == supervisorId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supervisor deleted successfully!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting supervisor: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false); // Stop loading
    }
  }

  Future<void> _toggleSupervisorStatus(String supervisorId) async {
    try {
      final currentData = await Supabase.instance.client
          .from('profiles')
          .select('status')
          .eq('id', supervisorId)
          .single();

      final currentStatus = currentData['status'] as String?;
      final newStatus = (currentStatus?.toLowerCase() != 'active') ? 'active' : 'inactive';

      await Supabase.instance.client
          .from('profiles')
          .update({'status': newStatus})
          .eq('id', supervisorId);

      final index = _supervisors.indexWhere((sup) => sup['id'] == supervisorId);
      if (index != -1) {
        _supervisors[index]['profiles'] = {'status': newStatus};
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status updated to "$newStatus"!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error toggling status: $e';
      });
    }
  }

  Future<void> _updateSupervisorTrainingCenter(String supervisorId) async {
    final supervisor = _supervisors.firstWhere(
          (sup) => sup['id'] == supervisorId,
      orElse: () => {},
    );

    final currentCenterId = supervisor['training_center_id']?.toString();
    final currentCenterName = (supervisor['training_centers'] is Map)
        ? supervisor['training_centers']['name']?.toString()
        : null;

    if (currentCenterId == null) {
      setState(() => _errorMessage = 'No training center assigned');
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: currentCenterName,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rename Training Center',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'New Center Name',
            hintText: 'Enter updated name',
            labelStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
            ),
            child: Text('Save', style: GoogleFonts.poppins()),
          )
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentCenterName) return;

    try {
      await Supabase.instance.client
          .from('training_centers')
          .update({'name': newName})
          .eq('id', currentCenterId);

      final index = _supervisors.indexWhere((sup) => sup['id'] == supervisorId);
      if (index != -1) {
        _supervisors[index]['training_centers'] = {
          ..._supervisors[index]['training_centers'],
          'name': newName
        };
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renamed to "$newName" successfully!', style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error renaming center: ${e.toString()}';
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _handlePopupAction(String action, String supervisorId) async {
    switch (action) {
      case 'delete':
        await _deleteSupervisor(supervisorId);
        break;
      case 'toggleStatus':
        await _toggleSupervisorStatus(supervisorId);
        break;
      case 'updateCenter':
        await _updateSupervisorTrainingCenter(supervisorId);
        break;
    }
  }

  Widget _buildSupervisorList() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: GoogleFonts.inter(color: Colors.red),
        ),
      );
    }
    if (_supervisors.isEmpty) {
      return Center(
        child: Text(
          'No supervisors found.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _supervisors.length,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (context, index) {
        final sup = _supervisors[index];
        final id = sup['id']?.toString() ?? '';
        final firstName = sup['first_name']?.toString() ?? '';
        final lastName = sup['last_name']?.toString() ?? '';
        final email = sup['email']?.toString() ?? '';
        final trainingCenter = (sup['training_centers'] is Map)
            ? (sup['training_centers']['name']?.toString() ?? '(none)')
            : '(none)';
        final status = (sup['profiles'] is Map)
            ? (sup['profiles']['status']?.toString() ?? 'unknown')
            : 'unknown';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.deepPurple.withOpacity(0.1),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(
              '$firstName $lastName',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: $email', style: GoogleFonts.inter(color: Colors.grey[600])),
                  Text('Training Center: $trainingCenter', style: GoogleFonts.inter(color: Colors.grey[600])),
                  Text(
                    'Status: ${status.toUpperCase()}',
                    style: GoogleFonts.inter(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handlePopupAction(value, id),
              icon: Icon(Icons.more_vert, color: Colors.deepPurple[800]),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'delete', child: Text('Delete Supervisor', style: GoogleFonts.inter())),
                PopupMenuItem(value: 'toggleStatus', child: Text('Toggle Status', style: GoogleFonts.inter())),
                PopupMenuItem(value: 'updateCenter', child: Text('Update Center', style: GoogleFonts.inter())),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          'Manage Supervisors',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _buildSupervisorList(),
    );
  }
}
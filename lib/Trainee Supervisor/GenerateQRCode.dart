import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:geocoding/geocoding.dart';

class GenerateQRCode extends StatefulWidget {
  final String email;

  const GenerateQRCode({super.key, required this.email});

  @override
  State<GenerateQRCode> createState() => _GenerateQRCodeState();
}

class _GenerateQRCodeState extends State<GenerateQRCode> {
  String? qrData;
  bool isGenerating = false;
  String? errorMessage;
  String? supervisorId;
  String? trainingCenterId;

  Future<void> _generateQRCode() async {
    setState(() {
      isGenerating = true;
      qrData = null;
      errorMessage = null;
    });

    try {
      await _validateSupervisor();
      final Position currentPosition = await _getLocation(); // Get current location
      final qrContent = await _createQrContent(currentPosition); // Pass position to create content
      await _storeQrCode(qrContent);
      // Update training center location
      await _updateTrainingCenterLocation(
        trainingCenterId!,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      setState(() => qrData = qrContent);
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => isGenerating = false);
    }
  }

  Future<void> _validateSupervisor() async {
    final normalizedEmail = widget.email.trim().toLowerCase();

    final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id, status')
        .ilike('email', normalizedEmail)
        .single();

    supervisorId = profileResponse['id'] as String?;
    final status = profileResponse['status'] as String?;

    if (status != 'active') {
      throw Exception("Account not approved by admin");
    }

    if (supervisorId == null || !_isValidUUID(supervisorId!)) {
      throw Exception("Invalid supervisor credentials");
    }

    final supervisorData = await Supabase.instance.client
        .from('supervisors')
        .select('training_center_id')
        .eq('id', supervisorId!)
        .single();

    trainingCenterId = supervisorData['training_center_id'] as String?;
    if (trainingCenterId == null || !_isValidUUID(trainingCenterId!)) {
      throw Exception("Invalid training center assignment");
    }
  }

  // MODIFIED: Now takes Position as input.
  Future<String> _createQrContent(Position position) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // Include latitude and longitude in the QR code data.
    return "trainingCenter|$trainingCenterId|$supervisorId|$timestamp|${position.latitude}|${position.longitude}";
  }

  Future<void> _storeQrCode(String content) async {
    await Supabase.instance.client.from('qr_codes').insert({
      'supervisor_id': supervisorId,
      'training_center_id': trainingCenterId,
      'qr_data': content, // Store the *full* QR data, including location.
      'generated_at': DateTime.now().toIso8601String(),
      'is_used': false,
    });
  }

  // NEW: Function to update training center location.
  Future<void> _updateTrainingCenterLocation(
      String centerId, double latitude, double longitude) async {
    await Supabase.instance.client
        .from('training_centers')
        .update({'latitude': latitude, 'longitude': longitude})
        .eq('id', centerId);
  }

  // NEW: Get the location
  Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw "Location services are disabled";

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission != LocationPermission.whileInUse &&
          newPermission != LocationPermission.always) {
        throw "Location permissions required";
      }
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _handleError(dynamic error) {
    setState(() {
      errorMessage =
      "Error: ${error.toString().replaceAll('Exception: ', '')}";
    });
  }

  bool _isValidUUID(String uuid) => RegExp(
    r"^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$",
  ).hasMatch(uuid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        title: Text(
          "Generate QR Code",
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (qrData != null) ...[
                QrImageView(
                  data: qrData!,
                  size: 250,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                ),
                const SizedBox(height: 20),
                Text(
                  'Valid for 5 minutes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    errorMessage!,
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 30),
              isGenerating
                  ? const CircularProgressIndicator(
                color: Colors.deepPurple,
              )
                  : ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_2, size: 24),
                label: Text(
                  "Generate New QR Code",
                  style: GoogleFonts.poppins(fontSize: 18),
                ),
                onPressed: _generateQRCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 15),
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
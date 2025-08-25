import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

class ScanQRCode extends StatefulWidget {
  final String studentEmail;

  const ScanQRCode({super.key, required this.studentEmail});

  @override
  State<ScanQRCode> createState() => _ScanQRCodeState();
}

class _ScanQRCodeState extends State<ScanQRCode> {
  String? scanResult;
  String? errorMessage;
  bool isScanning = false;
  bool cameraOpen = false;
  MobileScannerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(BarcodeCapture barcode) async {
    if (barcode.barcodes.isEmpty || isScanning || !mounted) return;

    setState(() {
      isScanning = true;
      errorMessage = null;
      scanResult = null;
    });

    try {
      final qrContent = barcode.barcodes.first.rawValue ?? "";
      debugPrint("QR scan initiated");

      // Validate QR format and length
      final qrParts = qrContent.split('|');
      if (qrParts.length != 6 || qrParts[0] != "trainingCenter") { // Now 6 parts
        throw "Invalid QR format. Expected: trainingCenter|trainingCenterId|supervisorId|timestamp|latitude|longitude";
      }

      // Extract data from QR code.
      final [_, trainingCenterId, supervisorId, timestamp, qrLatitude, qrLongitude] = qrParts; // Get lat/long
      if (!_isValidUUID(trainingCenterId) || !_isValidUUID(supervisorId)) {
        throw "Invalid ID format in QR code";
      }

      // --- Parse Latitude and Longitude ---
      final double? centerLatitude = double.tryParse(qrLatitude); // Parse to double
      final double? centerLongitude = double.tryParse(qrLongitude);

      if (centerLatitude == null || centerLongitude == null) {
        throw "Invalid location data in QR code.";
      }
      // ------------------------------------

      // Fetch student profile.
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .ilike('email', widget.studentEmail)
          .maybeSingle();

      final studentId = profileResponse?['id'];
      if (studentId == null) throw "Student not found";

      // Fetch the active round for the student.
      final activeRoundsResponse = await Supabase.instance.client
          .from('student_rounds')
          .select('''
            round_id, 
            rounds (
              start_date,
              end_date,
              leader_id
            )
          ''')
          .eq('student_id', studentId)
          .eq('status', 'in_progress')
          .limit(1);

      if (activeRoundsResponse.isEmpty) throw "No active round found";

      final activeRound = activeRoundsResponse.first;

      if (activeRound == null || activeRound['rounds'] == null) {
        throw "No active round found";
      }

      final roundId = activeRound['round_id'];
      final leaderId = activeRound['rounds']['leader_id'];

      if (leaderId != supervisorId) {
        throw "This supervisor is NOT assigned as the leader of this round.";
      }

      // Get Egypt time (UTC+2)
      final egyptNow = DateTime.now().toUtc().add(const Duration(hours: 2));
      final today = DateFormat('yyyy-MM-dd').format(egyptNow);

      // Parse round dates.
      final roundStartDate = DateTime.parse(activeRound['rounds']['start_date']);
      final roundEndDate = DateTime.parse(activeRound['rounds']['end_date']);

      // Validate round dates.
      if (egyptNow.isBefore(roundStartDate)) {
        throw "Round starts ${DateFormat('MMM dd, yyyy').format(roundStartDate)}";
      }
      if (egyptNow.isAfter(roundEndDate.add(const Duration(days: 1)))) {
        throw "Round ended ${DateFormat('MMM dd, yyyy').format(roundEndDate)}";
      }

      // Check existing attendance record.
      final existingRecord = await Supabase.instance.client
          .from('attendance')
          .select('id')
          .eq('student_id', studentId)
          .eq('scanned_date', today)
          .maybeSingle();

      if (existingRecord != null) throw "Attendance already recorded today";

      // --- LOCATION CHECK (Modified) ---
      // 1. Get Student's Current Location (You are already doing this)
      final studentPosition = await _getLocation();

      // 2. Calculate Distance (use QR code's lat/long)
      final distance = Geolocator.distanceBetween(
        studentPosition.latitude,
        studentPosition.longitude,
        centerLatitude,  // Use parsed latitude from QR
        centerLongitude, // Use parsed longitude from QR
      );

      // 3. Define and Check Threshold (NOW 20 METERS)
      const maxDistance = 20000000000.0; // Meters.  Changed to 20.
      if (distance > maxDistance) {
        throw "You are too far from the training center. Distance: ${distance.toStringAsFixed(0)} meters";
      }
      // --- END LOCATION CHECK ---

      // Get location data.
      final position = await _getLocation();  //Still get student location for the record
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).catchError((_) => []);
      final place = placemarks.isNotEmpty ? placemarks[0] : null;

      // ✅ Create attendance record.
      await Supabase.instance.client.from('attendance').insert({
        'student_id': studentId,
        'supervisor_id': supervisorId,
        'training_center_id': trainingCenterId,
        'attendance_code': qrContent,
        'scanned_at': egyptNow.toIso8601String(),
        'scanned_date': today,
        'location_city': place?.locality ?? "Unknown",
        'location_country': place?.country ?? "Unknown",
        'latitude': position.latitude,
        'longitude': position.longitude,
        'round_id': roundId,
      });

      setState(() {
        scanResult = "Attendance recorded successfully!";
        cameraOpen = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll(RegExp(r'^Exception: '), '');
        cameraOpen = false;
      });
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  // --- getLocation() (No changes, but included for completeness) ---
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

  bool _isValidUUID(String uuid) => RegExp(
    r"^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$",
  ).hasMatch(uuid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Scan QR Code",
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
        actions: [
          if (cameraOpen)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => cameraOpen = false),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFE9ECEF),
      body: Column(
        children: [
          Expanded(
            child: cameraOpen
                ? MobileScanner(
              controller: _controller,
              onDetect: _onQRViewCreated,
            )
                : Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (scanResult != null)
                      _StatusMessage(
                        message: scanResult!,
                        color: Colors.green,
                      ),
                    if (errorMessage != null)
                      _StatusMessage(
                        message: errorMessage!,
                        color: Colors.red,
                      ),
                    const SizedBox(height: 30),
                    isScanning
                        ? const CircularProgressIndicator(
                      color: Colors.deepPurple,
                    )
                        : ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        "Open QR Scanner",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => setState(() {
                        cameraOpen = true;
                        errorMessage = null;
                        scanResult = null;
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final Color color;

  const _StatusMessage({
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
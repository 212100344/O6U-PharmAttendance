// lib/Admin/Evaluation/AdminQRScannerScreen.dart

import 'package:attendance_sys/Admin/Evaluation/AllRoundsReportScreenAdmin.dart';
import 'package:attendance_sys/Admin/AdvancedEvaluationAdminScreen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminQRScannerScreen extends StatefulWidget {
  const AdminQRScannerScreen({Key? key}) : super(key: key);

  @override
  _AdminQRScannerScreenState createState() => _AdminQRScannerScreenState();
}

class _AdminQRScannerScreenState extends State<AdminQRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _screenOpened = false;

  // Local state variables for torch and camera facing
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  // Helper function to parse QR code data more safely
  Map<String, String?> _parseQrCodeData(String code) {
    final parts = code.split('|');
    final data = <String, String?>{};
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        data[keyValue[0]] = keyValue[1];
      }
    }
    print("Parsed QR Code Data: $data"); // Debug: Print the parsed data
    return data;
  }

  void _foundBarcode(BarcodeCapture barcode) async {
    if (barcode.barcodes.isEmpty || _screenOpened) {
      return;
    }

    final String code = barcode.barcodes.first.rawValue ?? "";
    if (code.isEmpty) {
      print("Error: Empty QR Code"); // Debug: Empty QR code
      return;
    }

    print("Raw QR Code Data: $code"); // Debug: Print raw QR code data

    _screenOpened = true; // Prevent multiple navigations

    try {
      final qrData = _parseQrCodeData(code);
      final reportType = qrData['reportType']; // Correctly parsed reportType
      final studentId = qrData['studentId'];

      print("Parsed Report Type: $reportType");
      print("Parsed Student ID: $studentId");

      if (studentId == null) {
        if (mounted) {
          _showErrorDialog("Invalid QR Code: Student ID missing.");
        }
        _screenOpened = false;
        return;
      }
      //CHANGE IS HERE: COMPARE DIRECTLY THE VALUE , CORRECT.
      if (reportType == "all") { // Compare directly with parsed value.
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AllRoundsReportScreenAdmin(studentId: studentId),
            ),
          ).then((value) => _screenOpened = false);
        }
      } else if (reportType == "single") { // Compare directly,CORRECT.
        final String? roundId = qrData['roundId']; // Change is here
        print("Parsed Round ID: $roundId"); // Debug: Parsed round ID

        if (roundId == null) {
          if (mounted) {
            _showErrorDialog("Invalid QR Code: Round ID missing.");
          }
          _screenOpened = false;
          return; // Exit early if roundId is null
        }

        final roundData = await _fetchRoundDetails(roundId);

        if (roundData != null) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdvancedEvaluationAdminScreen(
                  round: roundData, // Pass the entire round data
                  studentId: studentId,
                ),
              ),
            ).then((value) => _screenOpened = false);
          }
        } else {
          if (mounted) {
            _showErrorDialog("Round data not found for round ID: $roundId"); // More specific error
          }
          _screenOpened = false;
        }
      } else {
        if (mounted) {
          _showErrorDialog("Invalid QR Code format. Report type: $reportType"); // Show the invalid reportType
        }
        _screenOpened = false;
      }
    } catch (e) { // Catch any error during navigation or data parsing
      if (mounted) {
        _showErrorDialog("An error occurred: $e"); // More descriptive error
      }
      _screenOpened = false;
    }
  }

  Future<Map<String, dynamic>?> _fetchRoundDetails(String roundId) async {
    try {
      final response = await Supabase.instance.client
          .from('rounds')
          .select('*')
          .eq('id', roundId)
          .maybeSingle();
      print("Round data fetched: $response"); // Debug: Print fetched round data
      return response;
    } catch (e) {
      print("Error fetching round details: $e");
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
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
          "Scan Report QR Code",
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
          IconButton(
            color: Colors.white,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            iconSize: 32.0,
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          IconButton(
            color: Colors.white,
            icon: Icon(
              _cameraFacing == CameraFacing.back
                  ? Icons.camera_rear
                  : Icons.camera_front,
            ),
            iconSize: 32.0,
            onPressed: () {
              cameraController.switchCamera();
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back
                    ? CameraFacing.front
                    : CameraFacing.back;
              });
            },
          ),
        ],
      ),
      body: MobileScanner(
        onDetect: _foundBarcode,
        controller: cameraController,
      ),
    );
  }
}
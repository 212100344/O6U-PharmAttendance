// lib/Admin/pdf_service_admin.dart

import 'dart:typed_data';
import 'package:flutter/services.dart'; // Needed for rootBundle
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfServiceAdmin {
  static Future<Uint8List> generateReport({
    required Map<String, dynamic> student,
    required Map<String, dynamic> round,
    required int attendancePercentage,
    required String trainingCenterName,
    required String trainingCenterLocation,
    required String supervisorName,
    Uint8List? leftLogoBytes,
    Uint8List? rightLogoBytes,
    required String qrCodeData, // Add the QR code data parameter
  }) async {
    final fontData = await rootBundle.load('assets/Ubuntu-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/Ubuntu-Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/Ubuntu-Italic.ttf');

    final ubuntuRegular = pw.Font.ttf(fontData.buffer.asByteData());
    final ubuntuBold = pw.Font.ttf(fontBoldData.buffer.asByteData());
    final ubuntuItalic = pw.Font.ttf(fontItalicData.buffer.asByteData());

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ubuntuRegular,
        bold: ubuntuBold,
        italic: ubuntuItalic,
      ),
    );
    // Adjusted font sizes
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey600,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 9,
      color: PdfColors.grey800,
    );

    pdf.addPage(
      pw.MultiPage( // Use MultiPage
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 20), // Reduced top margin

        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 5),  // Space above the footer
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))
            ),
            child:pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                    style: labelStyle.copyWith(fontSize: 8)
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}", // Dynamic page number
                  style: labelStyle.copyWith(fontSize: 8),
                ),
              ],
            ),
          );
        },

        build: (pw.Context context) { // Return a list of widgets
          return [ pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (leftLogoBytes != null)
                    pw.Image(
                      pw.MemoryImage(leftLogoBytes),
                      height: 80, // Reduced size
                      width: 80,
                    ),
                  if (rightLogoBytes != null)
                    pw.Image(
                      pw.MemoryImage(rightLogoBytes),
                      height: 80, // Reduced size
                      width: 80,
                    ),
                ],
              ),
              pw.SizedBox(height: 10), // Reduced
              pw.Container(
                padding: const pw.EdgeInsets.all(16), // Reduced padding
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      "Round Evaluation Report",
                      style: headerStyle,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4, width: 50),
                    pw.Text(
                      round['name'] ?? 'Training Program',
                      style: pw.TextStyle(
                        fontSize: 17, // Reduced font size
                        color: PdfColors.green,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20), // Reduced
              _buildSection("Student Information", sectionStyle, [
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: _buildStudentDetails(
                    student: student,
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
              ]),
              pw.SizedBox(height: 15), // Reduced
              _buildSection("Attendance Summary", sectionStyle, [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        text: 'Overall Attendance: ',
                        style: labelStyle.copyWith(fontSize: 11), // Reduced
                        children: [
                          pw.TextSpan(
                            text: '$attendancePercentage%',
                            style: pw.TextStyle(
                              color: _getAttendanceColor(attendancePercentage),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 3), // Reduced
                    PdfServiceAdmin._buildEnhancedProgressBar(
                      attendancePercentage / 100,
                      _getAttendanceColor(attendancePercentage),
                    ),
                    pw.SizedBox(height: 2), // Reduced
                    pw.Text(
                      _getAttendanceStatus(attendancePercentage),
                      style: valueStyle.copyWith(
                        color: _getAttendanceColor(attendancePercentage),
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ]),
              pw.SizedBox(height: 15), // Reduced
              _buildSection("Training Center Details", sectionStyle, [
                pw.Container(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _buildIconDetailRow(
                        icon: '',
                        label: "Training Center:",
                        value: trainingCenterName,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      _buildIconDetailRow(
                        icon: '',
                        label: "Location:",
                        value: trainingCenterLocation,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      _buildIconDetailRow(
                        icon: '',
                        label: "Supervisor:",
                        value: supervisorName,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ],
                  ),
                ),
              ]),
              pw.SizedBox(height: 8), // Reduced
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  PdfServiceAdmin._buildEnhancedDateCard(
                    "Start Date",
                    round['start_date'],
                    PdfColors.blue900,
                  ),
                  PdfServiceAdmin._buildEnhancedDateCard(
                    "End Date",
                    round['end_date'],
                    PdfColors.blue900,
                  ),
                ],
              ),
              pw.SizedBox(height: 8), // Reduced
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), // Reduced padding
                child: pw.Text(
                  "This evaluation report has been generated to reveal the training progress, without any responsibility for incorrect information. \n\nForgery and manipulation of information in this file exposes the student to accountability in the university’s legal affairs department.",
                  style: valueStyle.copyWith(fontSize: 8, color: PdfColors.black), // Reduced font
                  textAlign: pw.TextAlign.left,
                ),
              ),


              // --- Signature Lines  ---
              pw.SizedBox(height: 20), //  space *BEFORE* signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end, // Align to bottom
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Supervisor Signature:", style: labelStyle),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        width: 180, // Adjust width as needed
                        height: 1,
                        color: PdfColors.grey,
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end, // Right-align
                    children: [
                      pw.Text("Faculty of Pharmacy Signature:", style: labelStyle),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        width: 180, // Adjust width as needed
                        height: 1,
                        color: PdfColors.grey,
                      ),
                    ],
                  ),
                ],
              ),
              // --- End of Signature Lines ---

              pw.SizedBox(height: 15), // Reduced

              // QR Code (NEW)
              pw.Center(
                child: pw.BarcodeWidget(
                  data: qrCodeData, // Use the passed data
                  barcode: pw.Barcode.qrCode(),
                  width: 80,  // Reduced
                  height: 80, // Reduced
                ),
              ),
              pw.SizedBox(height: 5),

            ],
          )];
        },
      ),
    );

    return pdf.save();
  }


  // NEW: Method for generating reports for multiple rounds
  static Future<Uint8List> generateAllRoundsReport({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> rounds, // Takes a List of rounds
    Uint8List? leftLogoBytes,
    Uint8List? rightLogoBytes,
    required String qrCodeData, // Add the QR code data parameter

  }) async {
    final fontData = await rootBundle.load('assets/Ubuntu-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/Ubuntu-Bold.ttf');
    final fontItalicData = await rootBundle.load('assets/Ubuntu-Italic.ttf');

    final ubuntuRegular = pw.Font.ttf(fontData.buffer.asByteData());
    final ubuntuBold = pw.Font.ttf(fontBoldData.buffer.asByteData());
    final ubuntuItalic = pw.Font.ttf(fontItalicData.buffer.asByteData());

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ubuntuRegular,
        bold: ubuntuBold,
        italic: ubuntuItalic,
      ),
    );

    final headerStyle = pw.TextStyle(
      fontSize: 19,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey600,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 9,
      color: PdfColors.grey800,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 20), // Reduced top margin,
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 5),
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                  style: labelStyle.copyWith(fontSize: 8),
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: labelStyle.copyWith(fontSize: 8),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          // Compute cumulative overall attendance from all rounds:
          final totalAttended = rounds.fold<int>(
              0, (sum, round) => sum + (round['attendedDays'] as int));
          final totalExpected = rounds.fold<int>(
              0, (sum, round) => sum + (round['expectedDays'] as int));
          final cumulativePercentage = totalExpected > 0
              ? ((totalAttended / totalExpected) * 100).round()
              : 0;

          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (leftLogoBytes != null)
                      pw.Image(
                        pw.MemoryImage(leftLogoBytes),
                        height: 80,
                        width: 80,
                      ),
                    if (rightLogoBytes != null)
                      pw.Image(
                        pw.MemoryImage(rightLogoBytes),
                        height: 80,
                        width: 80,
                      ),
                  ],
                ),
                pw.SizedBox(height: 10), // Reduced
                pw.Container(
                  padding: const pw.EdgeInsets.all(16), // Reduced padding
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "All Rounds Attendance Report",
                        style: headerStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4, width: 50),
                      pw.Text(
                        "Comprehensive Attendance Summary",
                        style: pw.TextStyle(
                          fontSize: 17, // Reduced
                          color: PdfColors.green,
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20), // Reduced
                _buildSection("Student Information", sectionStyle, [
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: _buildStudentDetails(
                      student: student,
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                ]),
                pw.SizedBox(height: 15), // Reduced

                // Attendance Section (for all rounds)
                _buildSection("Attendance Summary (All Rounds)", sectionStyle, [
                  pw.Table.fromTextArray(
                    context: context,
                    headerStyle: labelStyle.copyWith(fontSize: 9), // Reduced
                    cellStyle: valueStyle.copyWith(fontSize: 9),   // Reduced
                    headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                    cellAlignment: pw.Alignment.center, // All cells centered
                    data: <List<dynamic>>[
                      <dynamic>[
                        'Round',
                        'Start Date',
                        'End Date',
                        'Location',
                        'Supervisor',
                        'Attended',
                        'Expected',
                        '%'  // Changed header from "Attendance %" to "%"
                      ],
                      for (var round in rounds)
                        <dynamic>[
                          round['name'] ?? 'N/A',
                          DateFormat('yyyy-MM-dd')
                              .format(DateTime.parse(round['start_date'])),
                          DateFormat('yyyy-MM-dd')
                              .format(DateTime.parse(round['end_date'])),
                          round['location'] ?? 'N/A',
                          round['supervisorName'] ?? "N/A",
                          round['attendedDays'].toString(),
                          round['expectedDays'].toString(),
                          '${round['attendancePercentage']}%',
                        ],
                    ],
                    columnWidths: { // Adjust widths as needed
                      0: const pw.FixedColumnWidth(40), // Round Name
                      1: const pw.FixedColumnWidth(50), // Start Date
                      2: const pw.FixedColumnWidth(50), // End Date
                      3: const pw.FixedColumnWidth(70), // Location - might be long
                      4: const pw.FixedColumnWidth(45), // Supervisor
                      5: const pw.FixedColumnWidth(40), // Attended
                      6: const pw.FixedColumnWidth(40), // Expected
                      7: const pw.FixedColumnWidth(25), // % - very small
                    },
                  ),
                ]),
                pw.SizedBox(height: 8), // Reduced
                // Cumulative overall attendance with a colored percentage bar aligned to the left.
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Cumulative Overall Attendance: ",
                      style: valueStyle.copyWith(
                        fontSize: 10, // Reduced
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    _buildColoredPercentageBar(
                        cumulativePercentage / 100, cumulativePercentage),
                  ],
                ),
                pw.SizedBox(height: 20), // Reduced  space *BEFORE* signatures
                // Signature Lines
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Supervisor Signature:", style: labelStyle),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: 180,
                          height: 1,
                          color: PdfColors.grey,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Faculty of Pharmacy Signature:", style: labelStyle),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: 180,
                          height: 1,
                          color: PdfColors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), // Reduced
                  child: pw.Text(
                    "This evaluation report has been generated to reveal the training progress, without any responsibility for incorrect information. \n\nForgery and manipulation of information in this file exposes the student to accountability in the university’s legal affairs department.",
                    style: valueStyle.copyWith(
                        fontSize: 8, color: PdfColors.black),
                    textAlign: pw.TextAlign.left,
                  ),
                ),

                pw.SizedBox(height: 15),

                // QR Code (Centered)
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: qrCodeData,
                    barcode: pw.Barcode.qrCode(),
                    width: 80, // Reduced
                    height: 80, // Reduced
                  ),
                ),

              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSection(
      String title, pw.TextStyle style, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: style),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  static pw.Widget _buildStudentDetails({
    required Map<String, dynamic> student,
    required pw.TextStyle labelStyle,
    required pw.TextStyle valueStyle,
  }) {
    String getBirthday(String? nationalId) {
      if (nationalId == null || nationalId.isEmpty) {
        return "Unknown";
      }
      if (nationalId.length >= 7 && nationalId.startsWith("3")) {
        String yearPart = nationalId.substring(1, 3);
        String monthPart = nationalId.substring(3, 5);
        String dayPart = nationalId.substring(5, 7);
        int year = 2000 + int.parse(yearPart);
        int month = int.parse(monthPart);
        int day = int.parse(dayPart);
        return "$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}";
      }
      return "Unknown";
    }
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.5),
      },
      children: [
        _buildTableRow("Full Name", "${student['first_name']} ${student['last_name']}", labelStyle, valueStyle),
        _buildTableRow("Student ID", student['student_id'], labelStyle, valueStyle),
        _buildTableRow("National ID", student['national_id'], labelStyle, valueStyle),
        _buildTableRow(
          "Date of Birth",
          getBirthday(student['national_id'] ?? ''),
          labelStyle,
          valueStyle,
        ),
      ],
    );
  }

  static pw.TableRow _buildTableRow(
      String label,
      String value,
      pw.TextStyle labelStyle,
      pw.TextStyle valueStyle,
      ) {
    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(label, style: labelStyle),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: valueStyle),
        ),
      ],
    );
  }

  // Existing simple progress bar method
  static pw.Widget _buildProgressBar(double value) {
    final color = _getAttendanceColor((value * 100).round());
    return pw.ClipRect(
      child: pw.Container(
        height: 10,
        width: 60,
        child: pw.LinearProgressIndicator(
          value: value,
          backgroundColor: PdfColors.grey300,
          valueColor: color,
          minHeight: 10,
        ),
      ),
    );
  }

  // NEW: Enhanced progress bar that allows for an external color parameter.
  static pw.Widget _buildEnhancedProgressBar(double value, PdfColor color) {
    return pw.ClipRect(
      child: pw.Container(
        height: 10,  // Reduced
        width: 100, // Reduced
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.LinearProgressIndicator(
          value: value,
          backgroundColor: PdfColors.grey300,
          valueColor: color,
          minHeight: 10,
        ),
      ),
    );
  }

  // NEW: Colored percentage bar with overlaid percentage text.
  static pw.Widget _buildColoredPercentageBar(double value, int percentage) {
    return pw.Stack(
      children: [
        pw.Container(
          width: 80,  // Reduced
          height: 16, // Reduced
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(4),
          ),
        ),
        pw.Container(
          width: 80 * value, // Reduced
          height: 16, // Reduced
          decoration: pw.BoxDecoration(
            color: _getAttendanceColor(percentage),
            borderRadius: pw.BorderRadius.circular(4),
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          width: 80,  // Reduced
          height: 16, // Reduced
          child: pw.Text(
            "$percentage%",
            style: pw.TextStyle(
              fontSize: 9,  // Reduced
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildIconDetailRow({
    required String icon,
    required String label,
    required String value,
    required pw.TextStyle labelStyle,
    required pw.TextStyle valueStyle,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(icon, style: labelStyle),
          pw.SizedBox(width: 4),
          pw.Text(label, style: labelStyle),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: valueStyle,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getAttendanceColor(int percentage) {
    if (percentage >= 90) return PdfColors.green;
    if (percentage >= 75) return PdfColors.orange;
    return PdfColors.red;
  }

  static String _getAttendanceStatus(int percentage) {
    if (percentage >= 90) return 'Excellent Attendance';
    if (percentage >= 75) return 'Good Attendance';
    return 'Needs Improvement';
  }

  static pw.Widget _buildEnhancedDateCard(String title, String? date, PdfColor color) {
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(date))
        : 'N/A';

    return pw.Container(
      width: 100, // Reduced
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9, // Reduced
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Opacity(
            opacity: 0.1,
            child: pw.Container(
              width: double.infinity,
              height: 1,
              color: color,
            ),
          ),
          pw.Text(
            formattedDate,
            style: pw.TextStyle(
              fontSize: 9, // Reduced
              color: PdfColors.grey800,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
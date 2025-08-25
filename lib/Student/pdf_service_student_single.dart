// lib/Student/pdf_service_student_single.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfServiceStudentSingle {
  static Future<Uint8List> generateReport({
    required Map<String, dynamic> student,
    required Map<String, dynamic> round,
    required int attendancePercentage,
    required String trainingCenterName,
    required String trainingCenterLocation,
    required String supervisorName,
    required String Function(String) getBirthday,
    Uint8List? leftLogoBytes,
    Uint8List? rightLogoBytes,
    required String qrCodeData,
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

    // Restore some font sizes, but still smaller than original
    final headerStyle = pw.TextStyle(
      fontSize: 19,  // Was 18, original was 20
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 15,  // Was 14, original was 16
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 9, // Keep this small
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey600,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 9,  // Keep this small
      color: PdfColors.grey800,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 20), // Slightly more generous margins
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 5), // Keep top margin
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
                        height: 80, // Back to 80
                        width: 80,
                      ),
                    if (rightLogoBytes != null)
                      pw.Image(
                        pw.MemoryImage(rightLogoBytes),
                        height: 80, // Back to 80
                        width: 80,
                      ),
                  ],
                ),
                pw.SizedBox(height: 12), // Increased slightly
                pw.Container(
                  padding: const pw.EdgeInsets.all(16), // Back to 16
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "Round Training Evaluation Report",
                        style: headerStyle,
                        textAlign: pw.TextAlign.center,
                      ),
                      //  pw.SizedBox(height: 4, width: 50), // Removed to save some space
                      pw.Text(
                        round['name'] ?? 'Training Program',
                        style: pw.TextStyle(
                          fontSize: 17, // Slightly larger
                          color: PdfColors.green,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25), // Increased
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
                      getBirthday: getBirthday,
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                ]),
                pw.SizedBox(height: 20), // Increased slightly
                _buildSection("Attendance Summary", sectionStyle, [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          text: 'Overall Attendance: ',
                          style: labelStyle.copyWith(fontSize: 11), // Slightly smaller
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
                      pw.SizedBox(height: 5),
                      _buildEnhancedProgressBar(
                        attendancePercentage / 100,
                        _getAttendanceColor(attendancePercentage),
                      ),
                      pw.SizedBox(height: 3),
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
                pw.SizedBox(height: 20), // Increased slightly
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
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEnhancedDateCard(
                      "Start Date",
                      round['start_date'],
                      PdfColors.blue900,
                    ),
                    _buildEnhancedDateCard(
                      "End Date",
                      round['end_date'],
                      PdfColors.blue900,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8), // Reduced
                pw.Container(
                  padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), // Reduced
                  child: pw.Text(
                    "This evaluation report has been generated to reveal the training progress, without any responsibility for incorrect information. \n\nForgery and manipulation of information in this file exposes the student to accountability in the university’s legal affairs department.",
                    style:
                    valueStyle.copyWith(fontSize: 8, color: PdfColors.black), // Reduced
                    textAlign: pw.TextAlign.left,
                  ),
                ),


                // Signature Lines
                pw.SizedBox(height: 25), //  space *BEFORE* signatures
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
                          width: 180, // Reduced
                          height: 1,
                          color: PdfColors.grey,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Faculty Signature:", style: labelStyle),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: 180,  // Reduced
                          height: 1,
                          color: PdfColors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
                // --- End of Signature Lines ---
                pw.SizedBox(height: 15),
                // QR Code (Centered, added spacing)

                pw.Center(
                  child: pw.BarcodeWidget(
                    data: qrCodeData, // Use qrCodeData here
                    barcode: pw.Barcode.qrCode(),
                    width: 80,  // Reduced size
                    height: 80,
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

  // --- Helper Functions  ---
  static pw.Widget _buildSection(String title, pw.TextStyle style, List<pw.Widget> children) {
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
    required String Function(String) getBirthday,
    required pw.TextStyle labelStyle,
    required pw.TextStyle valueStyle,
  }) {
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


  static pw.Widget _buildEnhancedProgressBar(double value, PdfColor color) {
    return pw.Stack(
      children: [
        pw.Container(
          height: 10,  // Reduced height
          width: 150,  // Reduced width
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(5), // Slightly larger radius
          ),
        ),
        pw.Container(
          height: 10,  // Reduced height
          width: 150 * value, // Reduced width
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(5), // Slightly larger radius
          ),
          alignment: pw.Alignment.center,
          child: pw.Text( // Added text
            '${(value * 100).toStringAsFixed(1)}%', // Show percentage
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8, // Smaller font
              fontWeight: pw.FontWeight.bold,
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

  static pw.Widget _buildEnhancedDateCard(String title, String? date, PdfColor color) {
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(date))
        : 'N/A';

    return pw.Container(
      width: 100, // Reduced width
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
              fontSize: 10,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Opacity(
            opacity: 0.1,
            child: pw.Container(
              width: double.infinity,
              height: 1, // Reduced to a line
              color: color,
            ),
          ),
          pw.Text(
            formattedDate,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey800,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
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
}
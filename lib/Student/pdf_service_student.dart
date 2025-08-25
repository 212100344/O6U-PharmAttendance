// lib/Student/pdf_service_student.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfServiceStudent {
  static Future<Uint8List> generateReport({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> rounds,
    required String Function(String) getBirthday,
    Uint8List? leftLogoBytes,
    Uint8List? rightLogoBytes,
    required String qrCodeData, // Add QR code data parameter
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
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    final labelStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey600,
    );
    final valueStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColors.grey800,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
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
                        height: 90,
                        width: 90,
                      ),
                    if (rightLogoBytes != null)
                      pw.Image(
                        pw.MemoryImage(rightLogoBytes),
                        height: 90,
                        width: 90,
                      ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
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
                          fontSize: 18,
                          color: PdfColors.green,
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
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
                pw.SizedBox(height: 25),
                _buildSection("Attendance Summary (All Rounds)", sectionStyle, [
                  _buildAttendanceTable(rounds, labelStyle, valueStyle),
                  pw.SizedBox(height: 10),
                  _buildCumulativeProgressBar(rounds, valueStyle),
                ]),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding:
                  const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                  child: pw.Text(
                    "This evaluation report has been generated to reveal the training progress, without any responsibility for incorrect information. \n\nForgery and manipulation of information in this file exposes the student to accountability in the university’s legal affairs department.",
                    style: valueStyle.copyWith(
                        fontSize: 12, color: PdfColors.black),
                    textAlign: pw.TextAlign.left,
                  ),
                ),

                // QR Code (Centered, added spacing)
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: qrCodeData, // Use qrCodeData here
                    barcode: pw.Barcode.qrCode(),
                    width: 100,
                    height: 100,
                  ),
                ),
                pw.SizedBox(height: 5),
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
        _buildTableRow(
            "Full Name",
            "${student['first_name']} ${student['last_name']}",
            labelStyle,
            valueStyle),
        _buildTableRow(
            "Student ID", student['student_id'], labelStyle, valueStyle),
        _buildTableRow(
            "National ID", student['national_id'], labelStyle, valueStyle),
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
          child: pw.Text(label, style: labelStyle, textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: valueStyle, textAlign: pw.TextAlign.center),
        ),
      ],
    );
  }

  static pw.Widget _buildAttendanceTable(
      List<Map<String, dynamic>> rounds,
      pw.TextStyle labelStyle,
      pw.TextStyle valueStyle,
      ) {
    final headers = [
      'Round',
      'Start',
      'End',
      'Location',
      'Supervisor',
      'Attended',
      'Expected',
      '%'
    ];

    return pw.Table(
      columnWidths: {
        0: pw.IntrinsicColumnWidth(),
        1: pw.IntrinsicColumnWidth(),
        2: pw.IntrinsicColumnWidth(),
        3: pw.IntrinsicColumnWidth(),
        4: pw.IntrinsicColumnWidth(),
        5: pw.IntrinsicColumnWidth(),
        6: pw.IntrinsicColumnWidth(),
        7: pw.IntrinsicColumnWidth(),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((header) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                header,
                style: labelStyle,
                softWrap: false,
                maxLines: 1,
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        for (var round in rounds)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  round['name'] ?? 'N/A',
                  style: valueStyle,
                  softWrap: true,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  DateFormat('yyyy-MM-dd').format(DateTime.parse(round['start_date'])),
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  DateFormat('yyyy-MM-dd').format(DateTime.parse(round['end_date'])),
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  round['location'] ?? 'N/A',
                  style: valueStyle,
                  softWrap: true,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  round['supervisorName'] ?? 'N/A',
                  style: valueStyle,
                  softWrap: true,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  round['attendedDays'].toString(),
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  round['expectedDays'].toString(),
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '${round['attendancePercentage']}%',
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildCumulativeProgressBar(
      List<Map<String, dynamic>> rounds,
      pw.TextStyle valueStyle,
      ) {
    int totalAttended = 0;
    int totalExpected = 0;
    for (var round in rounds) {
      totalAttended += round['attendedDays'] is num
          ? (round['attendedDays'] as num).toInt()
          : int.tryParse(round['attendedDays'].toString()) ?? 0;

      totalExpected += round['expectedDays'] is num
          ? (round['expectedDays'] as num).toInt()
          : int.tryParse(round['expectedDays'].toString()) ?? 0;

    }
    double progress = totalExpected > 0 ? totalAttended / totalExpected : 0;
    int percentage = (progress * 100).round();
    final color = _getAttendanceColor(percentage);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          "Cumulative Attendance: $percentage%",
          style: valueStyle.copyWith(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        _buildEnhancedProgressBar(progress, color),
      ],
    );
  }

  static pw.Widget _buildEnhancedProgressBar(double value, PdfColor color) {
    return pw.Stack(
      children: [
        pw.Container(
          height: 20,
          width: 250,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(8),
          ),
        ),
        pw.Container(
          height: 20,
          width: 250 * value,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${(value * 100).toStringAsFixed(1)}%',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
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
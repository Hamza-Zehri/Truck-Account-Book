import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';

/// Generates and shares report exports. Kept deliberately simple: a single
/// summary page/sheet per export, matching what the Reports screen shows
/// on screen, rather than a full raw-data dump.
class ExportService {
  ExportService._();

  static Future<void> exportSummaryToPdf({
    required PeriodSummary summary,
    required String periodLabel,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Truck Account Book', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Report: $periodLabel', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              _pdfRow('Total Trips', '${summary.tripCount}'),
              _pdfRow('Total Income', formatMoney(summary.totalIncome)),
              _pdfRow('Total Expenses', formatMoney(summary.totalExpenses)),
              _pdfRow('Profit', formatMoney(summary.profit)),
              _pdfRow('Pending Payments', formatMoney(summary.pendingPayments)),
              pw.SizedBox(height: 20),
              pw.Text('Expense Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...summary.expenseBreakdown.entries.map((e) => _pdfRow(e.key, formatMoney(e.value))),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/truck_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    await Printing.sharePdf(bytes: bytes, filename: file.uri.pathSegments.last);
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
      ),
    );
  }

  static Future<void> exportSummaryToExcel({
    required PeriodSummary summary,
    required String periodLabel,
  }) async {
    final workbook = xls.Excel.createExcel();
    final sheet = workbook['Report'];
    sheet.appendRow([xls.TextCellValue('Truck Account Book - $periodLabel')]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Total Trips'), xls.IntCellValue(summary.tripCount)]);
    sheet.appendRow([xls.TextCellValue('Total Income'), xls.DoubleCellValue(summary.totalIncome)]);
    sheet.appendRow([xls.TextCellValue('Total Expenses'), xls.DoubleCellValue(summary.totalExpenses)]);
    sheet.appendRow([xls.TextCellValue('Profit'), xls.DoubleCellValue(summary.profit)]);
    sheet.appendRow([xls.TextCellValue('Pending Payments'), xls.DoubleCellValue(summary.pendingPayments)]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Expense Breakdown')]);
    for (final e in summary.expenseBreakdown.entries) {
      sheet.appendRow([xls.TextCellValue(e.key), xls.DoubleCellValue(e.value)]);
    }
    // Default 'Sheet1' comes with the workbook by default; drop it if empty.
    if (workbook.sheets.containsKey('Sheet1') && workbook.sheets.length > 1) {
      workbook.delete('Sheet1');
    }

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not generate Excel file');

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/truck_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Truck Account Book report ($periodLabel)');
  }
}

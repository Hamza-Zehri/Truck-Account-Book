import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truck_account_book/core/widgets/shared_widgets.dart';
import 'package:truck_account_book/data/repositories/report_repository.dart';

class ExportService {
  ExportService._();

  static Future<void> exportSummaryToPdf({
    required PeriodSummary summary,
    required String periodLabel,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 50, marginRight: 50, marginTop: 50, marginBottom: 60,
        ),
        header: (context) => pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MOH SIN MATERIAL SUPPLIER',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text('Financial Report', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
              pw.Text(periodLabel, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated ${DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Page ${context.pageNumber}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          _summaryTable(summary),
          pw.SizedBox(height: 24),
          if (summary.expenseBreakdown.isNotEmpty) ...[
            pw.Text('EXPENSE BREAKDOWN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            _expenseBreakdownTable(summary),
          ],
          pw.SizedBox(height: 24),
          _keyHighlights(summary),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mohsin_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    await Printing.sharePdf(bytes: bytes, filename: file.uri.pathSegments.last);
  }

  static pw.Widget _summaryTable(PeriodSummary s) {
    final profitColor = s.profit >= 0 ? PdfColors.green700 : PdfColors.red700;
    final rows = [
      _dataRow('Total Trips', '${s.tripCount}'),
      _dataRow('Total Income', formatMoney(s.totalIncome)),
      _dataRow('Total Expenses', formatMoney(s.totalExpenses)),
      _dataRow('Net Profit', formatMoney(s.profit), valueColor: profitColor, isBold: true),
      _dataRow('Pending Payments', formatMoney(s.pendingPayments)),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _headerCell('Summary'),
            _headerCell('Amount'),
          ],
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _expenseBreakdownTable(PeriodSummary s) {
    final entries = s.expenseBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _headerCell('Category'),
            _headerCell('Amount'),
          ],
        ),
        ...entries.map((e) => _dataRow(e.key, formatMoney(e.value))),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell(pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            _cell(pw.Text(formatMoney(s.totalExpenses),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ],
        ),
      ],
    );
  }

  static pw.Widget _keyHighlights(PeriodSummary s) {
    final profitLabel = s.profit >= 0 ? 'PROFITABLE' : 'LOSS';
    final profitColor = s.profit >= 0 ? PdfColors.green700 : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('KEY HIGHLIGHTS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 6),
          pw.Text(
            'This period shows $profitLabel operations with ${s.tripCount} trip(s), '
            '${formatMoney(s.totalIncome)} in total income, '
            '${formatMoney(s.totalExpenses)} in expenses, '
            'and a net profit of ${formatMoney(s.profit)}.',
            style: pw.TextStyle(fontSize: 10, color: profitColor),
          ),
          if (s.pendingPayments > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Pending payments amount to ${formatMoney(s.pendingPayments)}.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange700),
              ),
            ),
        ],
      ),
    );
  }

  static pw.TableRow _dataRow(String label, String value, {PdfColor? valueColor, bool isBold = false}) {
    return pw.TableRow(
      children: [
        _cell(pw.Text(label, style: pw.TextStyle(fontSize: 10))),
        _cell(pw.Text(value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
            textAlign: pw.TextAlign.right)),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _cell(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: child,
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
    if (workbook.sheets.containsKey('Sheet1') && workbook.sheets.length > 1) {
      workbook.delete('Sheet1');
    }

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not generate Excel file');

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mohsin_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Mohsin Material Supplier report ($periodLabel)');
  }
}

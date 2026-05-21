import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/account_model.dart';
import '../models/receipt_model.dart';

Future<Uint8List> buildReceiptPdf(
    Receipt receipt, AccountItem? account) async {
  final doc = pw.Document();
  final shortId = receipt.id.substring(0, 8).toUpperCase();

  const primary = PdfColor.fromInt(0xFF185FA5);
  const textSecondary = PdfColor.fromInt(0xFF6B7280);
  const borderColor = PdfColor.fromInt(0xFFE5E7EB);
  const rowAlt = PdfColor.fromInt(0xFFF5F5F4);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RECEIPT',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  pw.SizedBox(height: 4),
                  pw.Text('#$shortId',
                      style: const pw.TextStyle(
                          fontSize: 13, color: textSecondary)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Date',
                      style: const pw.TextStyle(
                          fontSize: 10, color: textSecondary)),
                  pw.SizedBox(height: 2),
                  pw.Text(_fmtDate(receipt.date),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: borderColor, thickness: 1),
          pw.SizedBox(height: 16),

          // ── Info section ─────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Paid By + Received In
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (receipt.paidBy != null &&
                        receipt.paidBy!.isNotEmpty) ...[
                      _field('Paid By', receipt.paidBy!),
                      pw.SizedBox(height: 12),
                    ],
                    _field('Received In', account?.accountName ?? '—'),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              // Right: Amount + Description
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _field('Amount', _fmtMoney(receipt.amount),
                        valueColor: primary,
                        valueBold: true,
                        valueFontSize: 16),
                    if (receipt.description != null &&
                        receipt.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      _field('Description', receipt.description!),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Items table ─────────────────────────────────────────────────
          if (receipt.items.isNotEmpty) ...[
            pw.SizedBox(height: 28),
            pw.Divider(color: borderColor, thickness: 1),
            pw.SizedBox(height: 14),
            _buildTable(receipt.items, receipt.amount, primary, rowAlt,
                textSecondary, borderColor),
          ],

          pw.Spacer(),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Divider(color: borderColor, thickness: 1),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text('Thank you for your business',
                style: const pw.TextStyle(
                    fontSize: 11, color: textSecondary)),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

// ─── helpers ────────────────────────────────────────────────────────────────

pw.Widget _field(
  String label,
  String value, {
  PdfColor? valueColor,
  bool valueBold = false,
  double valueFontSize = 13,
}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColor.fromInt(0xFF6B7280))),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: valueFontSize,
                fontWeight:
                    valueBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor ?? PdfColors.black)),
      ],
    );

pw.Widget _buildTable(
  List<ReceiptItem> items,
  double total,
  PdfColor primary,
  PdfColor rowAlt,
  PdfColor textSecondary,
  PdfColor borderColor,
) {
  return pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FixedColumnWidth(52),
      2: pw.FixedColumnWidth(96),
      3: pw.FixedColumnWidth(104),
    },
    border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: borderColor, width: 0.5)),
    children: [
      // Header
      pw.TableRow(
        decoration: pw.BoxDecoration(color: primary),
        children: [
          _th('Item', pw.TextAlign.left),
          _th('Qty', pw.TextAlign.right),
          _th('Unit Price', pw.TextAlign.right),
          _th('Total', pw.TextAlign.right),
        ],
      ),
      // Data rows
      ...items.asMap().entries.map((e) {
        final item = e.value;
        final even = e.key.isEven;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: even ? PdfColors.white : rowAlt),
          children: [
            _td(item.itemName, pw.TextAlign.left),
            _td(_fmtNumber(item.qty), pw.TextAlign.right),
            _td(_fmtMoney(item.unitPrice), pw.TextAlign.right,
                color: textSecondary),
            _td(_fmtMoney(item.total), pw.TextAlign.right, bold: true),
          ],
        );
      }),
      // Grand total row
      pw.TableRow(
        decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF9FAFB)),
        children: [
          _td('', pw.TextAlign.left),
          _td('', pw.TextAlign.left),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 9),
            child: pw.Text('Grand Total',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 9),
            child: pw.Text(_fmtMoney(total),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: primary)),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _th(String text, pw.TextAlign align) => pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );

pw.Widget _td(String text, pw.TextAlign align,
        {PdfColor? color, bool bold = false}) =>
    pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black)),
    );

// ─── formatting (mirrors format.dart, no Flutter dependency) ────────────────

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} / '
    '${d.month.toString().padLeft(2, '0')} / '
    '${d.year}';

String _fmtMoney(double v) => 'TZS ${_fmtNumber(v)}';

String _fmtNumber(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = _addCommas(parts[0]);
  return parts[1] == '00' ? intPart : '$intPart.${parts[1]}';
}

String _addCommas(String s) {
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

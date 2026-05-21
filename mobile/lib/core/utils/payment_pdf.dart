import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/account_model.dart';
import '../models/payment_model.dart';

Future<Uint8List> buildPaymentPdf(
    Payment payment, AccountItem? account) async {
  final doc = pw.Document();
  final shortId = payment.id.substring(0, 8).toUpperCase();

  const primary = PdfColor.fromInt(0xFF185FA5);
  const textSecondary = PdfColor.fromInt(0xFF6B7280);
  const borderColor = PdfColor.fromInt(0xFFE5E7EB);

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
                  pw.Text('PAYMENT',
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
                  pw.Text(_fmtDate(payment.date),
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
              // Left: Payee + Paid From
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (payment.payee != null &&
                        payment.payee!.isNotEmpty) ...[
                      _field('Payee', payment.payee!),
                      pw.SizedBox(height: 12),
                    ],
                    _field('Paid From', account?.accountName ?? '—'),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              // Right: Amount + Description
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _field('Amount', _fmtMoney(payment.amount),
                        valueColor: primary,
                        valueBold: true,
                        valueFontSize: 16),
                    if (payment.description != null &&
                        payment.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      _field('Description', payment.description!),
                    ],
                  ],
                ),
              ),
            ],
          ),

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

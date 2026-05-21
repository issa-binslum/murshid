import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Colors ───────────────────────────────────────────────────────────────────

const kPdfPrimary = PdfColor.fromInt(0xFF185FA5);
const kPdfTextSecondary = PdfColor.fromInt(0xFF6B7280);
const kPdfBorder = PdfColor.fromInt(0xFFE5E7EB);
const kPdfRowAlt = PdfColor.fromInt(0xFFF5F5F4);
const kPdfFooterBg = PdfColor.fromInt(0xFFF9FAFB);
const kPdfGreen = PdfColor.fromInt(0xFF16A34A);
const kPdfAmber = PdfColor.fromInt(0xFFF59E0B);
const kPdfRed = PdfColor.fromInt(0xFFDC2626);

// ── Column widths (same as Flutter table) ────────────────────────────────────

const kColWidths = {
  0: pw.FlexColumnWidth(4),
  1: pw.FixedColumnWidth(52),
  2: pw.FixedColumnWidth(96),
  3: pw.FixedColumnWidth(104),
};

// ── Formatting ───────────────────────────────────────────────────────────────

String pdfDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} / '
    '${d.month.toString().padLeft(2, '0')} / '
    '${d.year}';

String pdfMoney(double v) => 'TZS ${pdfNumber(v)}';

String pdfNumber(double v) {
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

// ── Info field ───────────────────────────────────────────────────────────────

pw.Widget pdfField(
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
                fontSize: 10, color: kPdfTextSecondary)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: valueFontSize,
                fontWeight:
                    valueBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor ?? PdfColors.black)),
      ],
    );

// ── Table cells ──────────────────────────────────────────────────────────────

pw.Widget pdfTh(String text, pw.TextAlign align) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );

pw.Widget pdfTd(String text, pw.TextAlign align,
        {PdfColor? color, bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black)),
    );

// ── Table header row ─────────────────────────────────────────────────────────

pw.TableRow pdfTableHeader() => pw.TableRow(
      decoration: pw.BoxDecoration(color: kPdfPrimary),
      children: [
        pdfTh('Item', pw.TextAlign.left),
        pdfTh('Qty', pw.TextAlign.right),
        pdfTh('Unit Price', pw.TextAlign.right),
        pdfTh('Total', pw.TextAlign.right),
      ],
    );

// ── Grand total row ───────────────────────────────────────────────────────────

pw.TableRow pdfGrandTotalRow(double total) => pw.TableRow(
      decoration: const pw.BoxDecoration(color: kPdfFooterBg),
      children: [
        pw.SizedBox(),
        pw.SizedBox(),
        pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: pw.Text('Grand Total',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: pw.Text(pdfMoney(total),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: kPdfPrimary)),
        ),
      ],
    );

// ── Status badge ─────────────────────────────────────────────────────────────

pw.Widget pdfStatusBadge(String status) {
  final PdfColor bg;
  final String label;
  switch (status) {
    case 'PAID':
      bg = kPdfGreen;
      label = 'Paid';
      break;
    case 'PARTIAL':
      bg = kPdfAmber;
      label = 'Partial';
      break;
    case 'CANCELLED':
      bg = kPdfRed;
      label = 'Cancelled';
      break;
    default:
      bg = kPdfTextSecondary;
      label = 'Unpaid';
  }
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
        color: bg, borderRadius: pw.BorderRadius.circular(4)),
    child: pw.Text(label,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white)),
  );
}

pw.Widget pdfCancelledBadge() => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
          color: kPdfRed, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text('CANCELLED',
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );

// ── Standard page footer ─────────────────────────────────────────────────────

pw.Widget pdfFooter() => pw.Column(
      children: [
        pw.Divider(color: kPdfBorder, thickness: 1),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text('Thank you for your business',
              style: const pw.TextStyle(
                  fontSize: 11, color: kPdfTextSecondary)),
        ),
      ],
    );

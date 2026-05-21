import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/purchase_model.dart';
import 'pdf_common.dart';

Future<Uint8List> buildPurchaseInvoicePdf(PurchaseInvoice invoice) async {
  final doc = pw.Document();
  final shortId = invoice.id.substring(0, 8).toUpperCase();

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
                  pw.Text('PURCHASE INVOICE',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: kPdfPrimary)),
                  pw.SizedBox(height: 4),
                  pw.Text('#$shortId',
                      style: const pw.TextStyle(
                          fontSize: 13, color: kPdfTextSecondary)),
                  pw.SizedBox(height: 6),
                  pdfStatusBadge(invoice.status),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice Date',
                      style: const pw.TextStyle(
                          fontSize: 10, color: kPdfTextSecondary)),
                  pw.SizedBox(height: 2),
                  pw.Text(pdfDate(invoice.date),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: kPdfBorder, thickness: 1),
          pw.SizedBox(height: 16),

          // ── Info ─────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pdfField('Supplier', invoice.supplierName),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pdfField('Total Amount', pdfMoney(invoice.total),
                        valueColor: kPdfPrimary,
                        valueBold: true,
                        valueFontSize: 16),
                    pw.SizedBox(height: 12),
                    pdfField('Paid', pdfMoney(invoice.paidAmount),
                        valueColor: kPdfGreen, valueBold: true),
                    if (invoice.balance > 0) ...[
                      pw.SizedBox(height: 12),
                      pdfField('Balance Due', pdfMoney(invoice.balance)),
                    ],
                    if (invoice.description != null &&
                        invoice.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      pdfField('Description', invoice.description!),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Items table ──────────────────────────────────────────────────
          if (invoice.items.isNotEmpty) ...[
            pw.SizedBox(height: 28),
            pw.Divider(color: kPdfBorder, thickness: 1),
            pw.SizedBox(height: 14),
            pw.Table(
              columnWidths: kColWidths,
              border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: kPdfBorder, width: 0.5)),
              children: [
                pdfTableHeader(),
                ...invoice.items.asMap().entries.map((e) {
                  final item = e.value;
                  final even = e.key.isEven;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: even ? PdfColors.white : kPdfRowAlt),
                    children: [
                      pdfTd(item.itemName, pw.TextAlign.left),
                      pdfTd(pdfNumber(item.qty), pw.TextAlign.right),
                      pdfTd(pdfMoney(item.unitPrice), pw.TextAlign.right,
                          color: kPdfTextSecondary),
                      pdfTd(pdfMoney(item.total), pw.TextAlign.right,
                          bold: true),
                    ],
                  );
                }),
                pdfGrandTotalRow(invoice.total),
              ],
            ),
          ],

          pw.Spacer(),
          pdfFooter(),
        ],
      ),
    ),
  );

  return doc.save();
}

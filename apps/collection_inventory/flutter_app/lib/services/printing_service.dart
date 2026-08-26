import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ai_command_service.dart';

class PrintingService {
  Future<void> printA4({
    required String invoiceNo,
    required String customer,
    required List<Map<String,dynamic>> items,
    required double total,
    required double paid,
    required double due,
    double discount = 0,
    String? discountReason,
    String qrStatus = 'not_applicable',
    String? luckyToken,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ignore: prefer_const_constructors
            pw.Text('GAJURMUKHI DAIRY & STORE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text('Value for Life'),
            pw.SizedBox(height: 12),
            pw.Text('Invoice: $invoiceNo'),
            pw.Text('Customer: $customer'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Item','Qty','Price','Total'],
              data: items.map((i) => [
                i['name'], '${i['qty']}', AppSettingsService.money(i['price'] as num), AppSettingsService.money(i['total'] as num)
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Align(alignment: pw.Alignment.centerRight,
              child: pw.Column(children: [
                if (discount > 0) pw.Text('Discount: -${AppSettingsService.money(discount)}${discountReason?.trim().isNotEmpty == true ? ' (${discountReason!.trim()})' : ''}'),
                pw.Text('Total: ${AppSettingsService.money(total)}'),
                pw.Text('Paid: ${AppSettingsService.money(paid)}'),
                pw.Text('Due: ${AppSettingsService.money(due)}'),
                if (qrStatus != 'not_applicable') pw.Text('QR payment: ${qrStatus == 'received' ? 'Received' : 'Pending confirmation'}'),
                if (luckyToken?.trim().isNotEmpty == true) pw.Text('Lucky draw token: ${luckyToken!.trim()}'),
              ])),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> printPos({
    required String invoiceNo,
    required String customer,
    required List<Map<String,dynamic>> items,
    required double total,
    required double paid,
    required double due,
    double discount = 0,
    String? discountReason,
    String qrStatus = 'not_applicable',
    String? luckyToken,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text('GAJURMUKHI DAIRY & STORE', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('Value for Life', style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 6),
        pw.Text('Invoice: $invoiceNo', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Customer: $customer', style: const pw.TextStyle(fontSize: 8)),
        pw.Text(DateTime.now().toLocal().toString().substring(0, 16), style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(),
        ...items.map((item) => pw.Row(children: [
          pw.Expanded(child: pw.Text('${item['name']}', style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(width: 26, child: pw.Text('${item['qty']}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(width: 56, child: pw.Text(AppSettingsService.money(item['total'] as num), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
        ])),
        pw.Divider(),
        if (discount > 0) pw.Text('Discount: -${AppSettingsService.money(discount)}${discountReason?.trim().isNotEmpty == true ? ' (${discountReason!.trim()})' : ''}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('TOTAL: ${AppSettingsService.money(total)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('PAID: ${AppSettingsService.money(paid)}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('BALANCE DUE: ${AppSettingsService.money(due)}', style: const pw.TextStyle(fontSize: 9)),
        if (qrStatus != 'not_applicable') pw.Text('QR: ${qrStatus == 'received' ? 'Payment received' : 'Pending confirmation'}', style: const pw.TextStyle(fontSize: 8)),
        if (luckyToken?.trim().isNotEmpty == true) ...[
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('LUCKY DRAW TOKEN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text(luckyToken!.trim(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('Keep this token for the monthly draw', style: const pw.TextStyle(fontSize: 7))),
        ],
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Thank you for shopping with us', style: const pw.TextStyle(fontSize: 8))),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<Uint8List> a4Bytes(String invoiceNo, double total) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('$invoiceNo • ${AppSettingsService.money(total)}'))));
    return doc.save();
  }
}

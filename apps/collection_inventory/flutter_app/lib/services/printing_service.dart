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

  Future<Uint8List> a4Bytes(String invoiceNo, double total) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('$invoiceNo • ${AppSettingsService.money(total)}'))));
    return doc.save();
  }
}

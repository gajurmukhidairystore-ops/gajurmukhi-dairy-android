import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintingService {
  Future<void> printA4({
    required String invoiceNo,
    required String customer,
    required List<Map<String,dynamic>> items,
    required double total,
    required double paid,
    required double due,
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
                i['name'], '${i['qty']}', 'NPR ${i['price']}', 'NPR ${i['total']}'
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Align(alignment: pw.Alignment.centerRight,
              child: pw.Column(children: [
                pw.Text('Total: NPR ${total.toStringAsFixed(2)}'),
                pw.Text('Paid: NPR ${paid.toStringAsFixed(2)}'),
                pw.Text('Due: NPR ${due.toStringAsFixed(2)}'),
              ])),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<Uint8List> a4Bytes(String invoiceNo, double total) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('$invoiceNo • NPR $total'))));
    return doc.save();
  }
}

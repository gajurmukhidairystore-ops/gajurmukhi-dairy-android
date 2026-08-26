import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'ai_command_service.dart';

enum ReceiptPaperWidth { mm58, mm80 }

class ThermalService {
  Future<Uint8List> buildReceipt({
    required String shop,
    required String invoiceNo,
    required List<Map<String,dynamic>> items,
    required double total,
    required double paid,
    required double due,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperWidth == ReceiptPaperWidth.mm58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text(shop,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text(invoiceNo, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    for (final i in items) {
      bytes += generator.row([
        PosColumn(text: '${i['name']}', width: 6),
        PosColumn(text: '${i['qty']}', width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: '${i['total']}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('TOTAL  ${AppSettingsService.money(total)}', styles: const PosStyles(bold: true));
    bytes += generator.text('PAID   ${AppSettingsService.money(paid)}');
    bytes += generator.text('DUE    ${AppSettingsService.money(due)}');
    bytes += generator.feed(2);
    bytes += generator.cut();
    return Uint8List.fromList(bytes);
  }
}

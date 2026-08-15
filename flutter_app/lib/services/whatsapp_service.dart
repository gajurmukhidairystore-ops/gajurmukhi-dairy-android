import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Uri messageUri(String phone, String message) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  }

  static String dailyTransactionMessage({
    required String invoiceNumber,
    required DateTime date,
    required List<Map<String, Object?>> items,
    required double subtotal,
    required double total,
    required double paid,
    String? customerName,
    String? customerPhone,
    double discount = 0,
    double? due,
    String? paymentMethod,
    String? upiId,
    String qrStatus = 'not_applicable',
  }) {
    String money(double value) => 'NPR ${value.toStringAsFixed(2)}';
    String qty(double value) => value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    String paymentLabel(String? value) {
      if (value == null || value.trim().isEmpty) return 'Not specified';
      return '${value[0].toUpperCase()}${value.substring(1)}';
    }

    final lines = items.isEmpty
        ? <String>['No line items recorded']
        : items.asMap().entries.map((entry) {
            final item = entry.value;
            final name = item['name']?.toString() ?? 'Item';
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
            final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
            final unit = item['unit']?.toString();
            final itemTotal = quantity * unitPrice;
            return '${entry.key + 1}. $name — ${qty(quantity)}${unit == null ? '' : ' $unit'} × ${money(unitPrice)} = ${money(itemTotal)}';
          }).toList();
    final balance = (due ?? total - paid).clamp(0, double.infinity).toDouble();
    final double safeDiscount = discount < 0 ? 0.0 : discount;
    final dateLabel = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return [
      '*GAJURMUKHI DAIRY & STORE*',
      '_Daily dairy transaction summary_',
      '────────────────────',
      '*Invoice:* $invoiceNumber',
      '*Date:* $dateLabel',
      '*Customer:* ${customerName?.trim().isNotEmpty == true ? customerName : 'Walk-in customer'}',
      if (customerPhone?.trim().isNotEmpty == true) '*Phone:* $customerPhone',
      '',
      '*Items*',
      ...lines,
      '',
      '*Subtotal:* ${money(subtotal)}',
      if (safeDiscount > 0) '*Discount:* -${money(safeDiscount)}',
      '*Total:* ${money(total)}',
      '*Paid:* ${money(paid < 0 ? 0 : paid)}',
      '*Balance due:* ${money(balance)}',
      '*Payment mode:* ${paymentLabel(paymentMethod)}',
      if (upiId?.trim().isNotEmpty == true) '*UPI:* $upiId',
      if (qrStatus != 'not_applicable') '*QR payment:* ${qrStatus == 'received' ? 'Received' : 'Pending confirmation'}',
      '',
      balance > 0
          ? 'Please settle the balance at your convenience.'
          : 'Payment received in full. Thank you!',
      'Value for Life',
    ].join('\n');
  }

  Future<void> shareInvoice(File pdf, String message) =>
      Share.shareXFiles([XFile(pdf.path)], text: message);

  Future<void> openMessage(String phone, String message) async {
    await launchUrl(messageUri(phone, message), mode: LaunchMode.externalApplication);
  }
}

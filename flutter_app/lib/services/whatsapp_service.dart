import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_command_service.dart';

class WhatsAppService {
  static const defaultTemplate = '''*GAJURMUKHI DAIRY & STORE*
_Daily dairy transaction summary_
────────────────────
*Invoice:* {{invoiceNumber}}
*Date:* {{date}}
*Customer:* {{customerName}}
{{customerPhoneLine}}

*Items*
{{items}}

*Subtotal:* {{subtotal}}
{{discountLine}}
*Total:* {{orderTotal}}
*Paid:* {{paid}}
*Balance due:* {{balanceDue}}
*Payment mode:* {{paymentMode}}
{{upiLine}}
{{qrStatusLine}}
{{luckyTokenLine}}

{{paymentNote}}
Value for Life''';

  static const supportedVariables = <String>[
    '{{invoiceNumber}}',
    '{{date}}',
    '{{customerName}}',
    '{{customerPhone}}',
    '{{customerPhoneLine}}',
    '{{items}}',
    '{{subtotal}}',
    '{{discount}}',
    '{{discountLine}}',
    '{{orderTotal}}',
    '{{paid}}',
    '{{balanceDue}}',
    '{{paymentMode}}',
    '{{upiId}}',
    '{{upiLine}}',
    '{{qrStatus}}',
    '{{qrStatusLine}}',
    '{{luckyToken}}',
    '{{luckyTokenLine}}',
    '{{paymentNote}}',
  ];

  static Uri messageUri(String phone, String message) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  }

  static List<String> unsupportedVariables(String template) {
    final matches = RegExp(r'{{[^{}]+}}').allMatches(template).map((m) => m.group(0)!).toSet();
    return matches.where((token) => !supportedVariables.contains(token)).toList();
  }

  static String normalizeTemplate(String? template) {
    final value = template?.trim();
    if (value == null || value.isEmpty || unsupportedVariables(value).isNotEmpty) return defaultTemplate;
    return value;
  }

  static String renderTemplate({required String template, required Map<String, String> values}) {
    return normalizeTemplate(template).replaceAllMapped(RegExp(r'{{([A-Za-z][A-Za-z0-9]*)}}'), (match) => values[match.group(1)] ?? '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
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
    String? discountReason,
    double? due,
    String? paymentMethod,
    String? upiId,
    String qrStatus = 'not_applicable',
    String? luckyToken,
    String? template,
  }) {
    String money(double value) => AppSettingsService.money(value);
    String qty(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
    String paymentLabel(String? value) {
      if (value == null || value.trim().isEmpty) return 'Not specified';
      return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
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
    final safeDiscount = discount < 0 ? 0.0 : discount;
    final dateLabel = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final phone = customerPhone?.trim() ?? '';
    final qrLabel = qrStatus == 'received' ? 'Received' : qrStatus == 'pending' ? 'Pending confirmation' : 'Not applicable';

    return renderTemplate(template: template ?? defaultTemplate, values: {
      'invoiceNumber': invoiceNumber,
      'date': dateLabel,
      'customerName': customerName?.trim().isNotEmpty == true ? customerName!.trim() : 'Walk-in customer',
      'customerPhone': phone,
      'customerPhoneLine': phone.isEmpty ? '' : '*Phone:* $phone',
      'items': lines.join('\n'),
      'subtotal': money(subtotal),
      'discount': money(safeDiscount),
      'discountLine': safeDiscount > 0 ? '*Discount:* -${money(safeDiscount)}${discountReason?.trim().isNotEmpty == true ? ' (${discountReason!.trim()})' : ''}' : '',
      'orderTotal': money(total),
      'paid': money(paid < 0 ? 0 : paid),
      'balanceDue': money(balance),
      'paymentMode': paymentLabel(paymentMethod),
      'upiId': upiId?.trim() ?? '',
      'upiLine': upiId?.trim().isNotEmpty == true ? '*UPI:* ${upiId!.trim()}' : '',
      'qrStatus': qrLabel,
      'qrStatusLine': qrStatus != 'not_applicable' ? '*QR payment:* $qrLabel' : '',
      'luckyToken': luckyToken?.trim() ?? '',
      'luckyTokenLine': luckyToken?.trim().isNotEmpty == true ? '*Lucky draw token:* ${luckyToken!.trim()}' : '',
      'paymentNote': balance > 0 ? 'Please settle the balance at your convenience.' : 'Payment received in full. Thank you!',
    });
  }

  Future<void> shareInvoice(File pdf, String message) => Share.shareXFiles([XFile(pdf.path)], text: message);

  Future<void> openMessage(String phone, String message) async {
    await launchUrl(messageUri(phone, message), mode: LaunchMode.externalApplication);
  }
}

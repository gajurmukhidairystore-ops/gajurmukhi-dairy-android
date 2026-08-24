class BusinessCalculations {
  static double invoiceTotal({required double subtotal, required double discount}) => (subtotal - discount).clamp(0, double.infinity).toDouble();
  static double taxAmount({required double subtotal, required double discount, required double taxRate}) {
    final taxable = invoiceTotal(subtotal: subtotal, discount: discount);
    return taxable * (taxRate.clamp(0, 100) / 100);
  }
  static double invoiceTotalWithTax({required double subtotal, required double discount, required double taxRate}) => invoiceTotal(subtotal: subtotal, discount: discount) + taxAmount(subtotal: subtotal, discount: discount, taxRate: taxRate);
  static double paymentTotal(Iterable<Map<String, Object?>> payments) => payments.fold(0, (sum, payment) => sum + ((payment['amount'] as num?)?.toDouble() ?? 0));
  static bool isPaymentBalanced({required double total, required Iterable<Map<String, Object?>> payments}) => (paymentTotal(payments) - total).abs() < 0.01;
  static double cashChange({required double total, required double cashReceived}) => (cashReceived - total).clamp(0, double.infinity).toDouble();
  static bool isLowStock({required double stock, required double threshold}) => stock <= threshold;
  static String variantLabel({String? size, String? color, String? sku}) => [if (size?.trim().isNotEmpty == true) size!.trim(), if (color?.trim().isNotEmpty == true) color!.trim(), if (sku?.trim().isNotEmpty == true) 'SKU ${sku!.trim()}'].join(' • ');
  static double due({required double total, required double paid}) => (total - paid).clamp(0, double.infinity).toDouble();
  static double stockAfterSale({required double stock, required double quantity}) => (stock - quantity).clamp(0, double.infinity).toDouble();
  static double stockAfterReturn({required double stock, required double quantity, required String type}) => type == 'SALE_RETURN' ? stock + quantity : (stock - quantity).clamp(0, double.infinity).toDouble();
  static double stockAfterMilkCollection({required double stock, required double litres}) => (stock + litres).clamp(0, double.infinity).toDouble();
  static double stockAfterMilkCollectionRemoval({required double stock, required double litres}) => (stock - litres).clamp(0, double.infinity).toDouble();
  static bool isValidBarcode(String value) => value.trim().isEmpty || RegExp(r'^[0-9A-Za-z-]{4,40}$').hasMatch(value.trim());
  static bool isValidCreditReminder({required double amount, required String customerId}) => amount > 0 && customerId.trim().isNotEmpty;
  static double ledgerBalance({required double opening, required Iterable<Map<String, Object?>> entries}) => entries.fold(opening, (sum, entry) { final amount = (entry['amount'] as num?)?.toDouble() ?? 0; return sum + (entry['type'] == 'SALE_DUE' ? amount : -amount); });
  static double matchRate({required double fat, required double snf, required Iterable<Map<String, Object?>> rules, required double fallbackRate}) { for (final rule in rules) { final fatMin = (rule['fat_min'] as num).toDouble(); final fatMax = (rule['fat_max'] as num).toDouble(); final snfMin = (rule['snf_min'] as num).toDouble(); final snfMax = (rule['snf_max'] as num).toDouble(); if (fat >= fatMin && fat <= fatMax && snf >= snfMin && snf <= snfMax) return (rule['rate'] as num).toDouble(); } return fallbackRate; }
}

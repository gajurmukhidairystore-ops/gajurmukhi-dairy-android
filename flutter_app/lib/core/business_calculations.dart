class BusinessCalculations {
  static double invoiceTotal({required double subtotal, required double discount}) => (subtotal - discount).clamp(0, double.infinity).toDouble();
  static double due({required double total, required double paid}) => (total - paid).clamp(0, double.infinity).toDouble();
  static double stockAfterSale({required double stock, required double quantity}) => (stock - quantity).clamp(0, double.infinity).toDouble();
  static double stockAfterReturn({required double stock, required double quantity, required String type}) => type == 'SALE_RETURN' ? stock + quantity : (stock - quantity).clamp(0, double.infinity).toDouble();
  static bool isValidBarcode(String value) => value.trim().isEmpty || RegExp(r'^[0-9A-Za-z-]{4,40}$').hasMatch(value.trim());
  static bool isValidCreditReminder({required double amount, required String customerId}) => amount > 0 && customerId.trim().isNotEmpty;
  static double ledgerBalance({required double opening, required Iterable<Map<String, Object?>> entries}) => entries.fold(opening, (sum, entry) { final amount = (entry['amount'] as num?)?.toDouble() ?? 0; return sum + (entry['type'] == 'SALE_DUE' ? amount : -amount); });
  static double matchRate({required double fat, required double snf, required Iterable<Map<String, Object?>> rules, required double fallbackRate}) { for (final rule in rules) { final fatMin = (rule['fat_min'] as num).toDouble(); final fatMax = (rule['fat_max'] as num).toDouble(); final snfMin = (rule['snf_min'] as num).toDouble(); final snfMax = (rule['snf_max'] as num).toDouble(); if (fat >= fatMin && fat <= fatMax && snf >= snfMin && snf <= snfMax) return (rule['rate'] as num).toDouble(); } return fallbackRate; }
}

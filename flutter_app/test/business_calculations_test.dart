import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/core/business_calculations.dart';
import 'package:gajurmukhi_dairy_business_pro/services/sync_coordinator.dart';
import 'package:gajurmukhi_dairy_business_pro/services/whatsapp_service.dart';

void main() {
  test('invoice totals and due are never negative', () {
    final total = BusinessCalculations.invoiceTotal(subtotal: 120, discount: 10);
    expect(total, 110);
    expect(BusinessCalculations.due(total: total, paid: 125), 0);
  });

  test('stock reduction never produces negative inventory', () {
    expect(BusinessCalculations.stockAfterSale(stock: 12, quantity: 5), 7);
    expect(BusinessCalculations.stockAfterSale(stock: 2, quantity: 5), 0);
  });

  test('ledger balance treats sale due as debit and payments as credit', () {
    final balance = BusinessCalculations.ledgerBalance(opening: 100, entries: [
      {'type': 'SALE_DUE', 'amount': 500},
      {'type': 'PAYMENT', 'amount': 125},
    ]);
    expect(balance, 475);
  });

  test('FAT/SNF matching uses configured range and fallback', () {
    final rules = [
      {'fat_min': 3, 'fat_max': 4.5, 'snf_min': 8, 'snf_max': 9, 'rate': 42},
    ];
    expect(BusinessCalculations.matchRate(fat: 4, snf: 8.5, rules: rules, fallbackRate: 35), 42);
    expect(BusinessCalculations.matchRate(fat: 5, snf: 8.5, rules: rules, fallbackRate: 35), 35);
  });

  test('sync envelope decodes queued JSON and preserves source metadata', () {
    final envelope = buildSyncEnvelope({
      'id': 'queue-7',
      'entity': 'invoice',
      'entity_id': 'invoice-12',
      'operation': 'upsert',
      'payload': '{"total": 250, "paid": 200}',
      'created_at': 1700000000000,
    });

    expect(envelope['sync_id'], 'queue-7');
    expect(envelope['entity_id'], 'invoice-12');
    expect(envelope['payload'], {'total': 250, 'paid': 200});
  });

  test('WhatsApp invoice URI strips formatting and encodes the message', () {
    final uri = WhatsAppService.messageUri('+977 981-234-5678', 'Invoice total: NPR 250');

    expect(uri.host, 'wa.me');
    expect(uri.path, '/9779812345678');
    expect(uri.queryParameters['text'], 'Invoice total: NPR 250');
  });
}

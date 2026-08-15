import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/core/business_calculations.dart';
import 'package:gajurmukhi_dairy_business_pro/services/sync_coordinator.dart';
import 'package:gajurmukhi_dairy_business_pro/services/whatsapp_service.dart';
import 'package:gajurmukhi_dairy_business_pro/services/role_permissions.dart';

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

  test('role permissions separate admin, shop, and collector workflows', () {
    expect(RolePermissions.canAccess('admin', 6), isTrue);
    expect(RolePermissions.canAccess('shop', 1), isTrue);
    expect(RolePermissions.canAccess('shop', 4), isFalse);
    expect(RolePermissions.canAccess('collector', 4), isTrue);
    expect(RolePermissions.canAccess('collector', 1), isFalse);
  });

  test('WhatsApp daily summary includes itemized payment details', () {
    final message = WhatsAppService.dailyTransactionMessage(
      invoiceNumber: 'INV-2026-001',
      date: DateTime(2026, 8, 15, 9, 30),
      customerName: 'Sita Sharma',
      customerPhone: '+977 9812345678',
      items: [
        {'name': 'Fresh milk', 'quantity': 2, 'unitPrice': 90, 'unit': 'L'},
        {'name': 'Curd', 'quantity': 1, 'unitPrice': 75, 'unit': 'pack'},
      ],
      subtotal: 255,
      discount: 5,
      total: 250,
      paid: 200,
      paymentMethod: 'credit',
    );

    expect(message, contains('*GAJURMUKHI DAIRY & STORE*'));
    expect(message, contains('*Invoice:* INV-2026-001'));
    expect(message, contains('*Customer:* Sita Sharma'));
    expect(message, contains('1. Fresh milk — 2 L × NPR 90.00 = NPR 180.00'));
    expect(message, contains('*Discount:* -NPR 5.00'));
    expect(message, contains('*Balance due:* NPR 50.00'));
    expect(message, contains('*Payment mode:* Credit'));
  });

  test('WhatsApp invoice URI strips formatting and encodes the message', () {
    final uri = WhatsAppService.messageUri('+977 981-234-5678', 'Invoice total: NPR 250');

    expect(uri.host, 'wa.me');
    expect(uri.path, '/9779812345678');
    expect(uri.queryParameters['text'], 'Invoice total: NPR 250');
  });
}

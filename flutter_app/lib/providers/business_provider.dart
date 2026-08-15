import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';

class BusinessProvider extends ChangeNotifier {
  final AppDatabase db;
  final uuid = const Uuid();

  List<Map<String,Object?>> customers = [];
  List<Map<String,Object?>> products = [];
  List<Map<String,Object?>> farmers = [];
  List<Map<String,Object?>> milk = [];
  Map<String,num> totals = {};

  BusinessProvider(this.db);

  Future<void> bootstrap() async {
    await refresh();
    if (products.isEmpty) {
      await addProduct('Milk 1 Ltr', 90, 100, unit: 'Litre', category: 'Dairy');
      await addProduct('Dahi 1 Cup', 30, 50, unit: 'Cup', category: 'Dairy');
      await addProduct('Paneer 1 Kg', 800, 10, unit: 'Kg', category: 'Dairy');
    }
  }

  Future<void> refresh() async {
    customers = await db.query('customers', where: 'active=1');
    products = await db.query('products', where: 'active=1');
    farmers = await db.query('farmers', where: 'active=1');
    milk = await db.query('milk_collections', where: 'collection_date=date("now","localtime")');
    totals = await db.totals();
    notifyListeners();
  }

  Future<void> addCustomer(String name, String phone, String address) async {
    final id = uuid.v4();
    final row = {'id': id, 'name': name, 'phone': phone, 'address': address, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('customers', row);
    await db.enqueueSync(entity: 'customers', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> adjustStock(String productId, double delta, String note) async {
    Map<String, Object?>? product;
    for (final row in products) {
      if ('${row['id']}' == productId) { product = row; break; }
    }
    if (product == null || delta == 0) return;
    final current = (product['stock'] as num?)?.toDouble() ?? 0;
    final next = (current + delta).clamp(0, double.infinity).toDouble();
    await db.db.rawUpdate('UPDATE products SET stock=? WHERE id=?', [next, productId]);
    final movementId = uuid.v4();
    final movement = {'id': movementId, 'product_id': productId, 'type': delta > 0 ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT', 'qty': delta, 'unit_cost': product['purchase_price'] ?? 0, 'note': note, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('stock_movements', movement);
    await db.enqueueSync(entity: 'stock_movements', entityId: movementId, operation: 'upsert', payload: movement);
    await refresh();
  }

  Future<void> addProduct(String name, double price, double stock,
      {String unit='Unit', String category='General', String barcode=''}) async {
    final id = uuid.v4();
    final row = {'id': id, 'name': name, 'category': category, 'unit': unit, 'sale_price': price, 'purchase_price': 0, 'stock': stock, 'low_stock': 5, 'barcode': barcode.trim(), 'active': 1};
    await db.insert('products', row);
    await db.enqueueSync(entity: 'products', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> addFarmer(String name, String phone, String address, double rate) async {
    final id = uuid.v4();
    final row = {'id': id, 'name': name, 'phone': phone, 'address': address, 'rate_per_litre': rate, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('farmers', row);
    await db.enqueueSync(entity: 'farmers', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> addMilkCollection({
    required String farmerId,
    required double litres,
    required double fat,
    required double snf,
    required double rate,
    required String shift,
  }) async {
    if (farmerId.trim().isEmpty) throw ArgumentError('Select a farmer before saving');
    if (litres <= 0) throw ArgumentError('Milk litres must be greater than zero');
    if (fat <= 0 || snf <= 0) throw ArgumentError('FAT and SNF must be greater than zero');
    if (rate <= 0) throw ArgumentError('Rate per litre must be greater than zero');
    final now = DateTime.now();
    final id = uuid.v4();
    final row = {'id': id, 'farmer_id': farmerId, 'collection_date': now.toIso8601String().substring(0,10), 'shift': shift, 'litres': litres, 'fat': fat, 'snf': snf, 'rate': rate, 'amount': litres * rate, 'created_at': now.toIso8601String()};
    await db.insert('milk_collections', row);
    await db.enqueueSync(entity: 'milk_collections', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> removeMilkCollection(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('Collection id is required');
    final removed = await db.delete('milk_collections', id);
    if (removed == 0) throw StateError('Collection record was not found');
    await db.enqueueSync(entity: 'milk_collections', entityId: id, operation: 'delete', payload: {'id': id});
    await refresh();
  }

  Future<List<Map<String, Object?>>> customerLedger(String customerId) async {
    return db.query('ledger', where: 'customer_id=?', args: [customerId]);
  }

  Future<void> recordAdvance(String? customerId, double amount, String method, String note) async {
    final now = DateTime.now().toIso8601String();
    final id = uuid.v4();
    await db.insert('advances', {
      'id': id, 'customer_id': customerId, 'amount': amount,
      'method': method, 'note': note, 'created_at': now
    });
    if (customerId != null) {
      await db.db.rawUpdate('UPDATE customers SET balance=balance-? WHERE id=?', [amount, customerId]);
      await db.insert('ledger', {
        'id': uuid.v4(), 'customer_id': customerId, 'type': 'ADVANCE',
        'amount': amount, 'reference_id': id, 'note': note, 'created_at': now
      });
    }
    await refresh();
  }

  Future<void> recordPayment(String? customerId, double amount, String method, String note) async {
    final now = DateTime.now().toIso8601String();
    final id = uuid.v4();
    await db.insert('payments', {
      'id': id, 'customer_id': customerId, 'amount': amount,
      'method': method, 'note': note, 'created_at': now
    });
    if (customerId != null) {
      await db.db.rawUpdate('UPDATE customers SET balance=balance-? WHERE id=?', [amount, customerId]);
      await db.insert('ledger', {
        'id': uuid.v4(), 'customer_id': customerId, 'type': 'PAYMENT',
        'amount': amount, 'reference_id': id, 'note': note, 'created_at': now
      });
    }
    await refresh();
  }

  Future<void> recordExpense(String category, double amount, String method, String note) async {
    if (amount <= 0) throw ArgumentError('Payment out amount must be greater than zero');
    final id = uuid.v4();
    final row = {'id': id, 'category': category, 'amount': amount, 'method': method, 'note': note, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('expenses', row);
    await db.enqueueSync(entity: 'expenses', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> recordReturn({required String type, required String productId, required double qty, required double amount, String? partyId, String? referenceId, String note = ''}) async {
    if (qty <= 0 || amount < 0) throw ArgumentError('Return quantity must be greater than zero');
    if (type != 'SALE_RETURN' && type != 'PURCHASE_RETURN') throw ArgumentError('Unsupported return type');
    final id = uuid.v4();
    final now = DateTime.now().toIso8601String();
    final stockDelta = type == 'SALE_RETURN' ? qty : -qty;
    await db.db.transaction((txn) async {
      await txn.rawUpdate('UPDATE products SET stock=MAX(0, stock+?) WHERE id=?', [stockDelta, productId]);
      await txn.insert('returns', {'id': id, 'type': type, 'product_id': productId, 'qty': qty, 'amount': amount, 'party_id': partyId, 'reference_id': referenceId, 'note': note, 'created_at': now});
      await txn.insert('stock_movements', {'id': uuid.v4(), 'product_id': productId, 'type': type, 'qty': stockDelta, 'unit_cost': amount / qty, 'reference_id': id, 'note': note, 'created_at': now});
    });
    await db.enqueueSync(entity: 'returns', entityId: id, operation: 'upsert', payload: {'id': id, 'type': type, 'product_id': productId, 'qty': qty, 'amount': amount, 'party_id': partyId, 'reference_id': referenceId, 'note': note, 'created_at': now});
    await refresh();
  }

  Future<void> createCreditReminder({required String customerId, required double amount, required String channel, required String message}) async {
    if (amount <= 0) throw ArgumentError('Reminder amount must be greater than zero');
    final id = uuid.v4();
    final row = {'id': id, 'customer_id': customerId, 'amount': amount, 'channel': channel, 'message': message, 'status': 'PENDING', 'created_at': DateTime.now().toIso8601String()};
    await db.insert('credit_reminders', row);
    await db.enqueueSync(entity: 'credit_reminders', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> createInvoice({
    String? customerId,
    required List<Map<String,dynamic>> items,
    required double discount,
    required double paid,
    required String paymentMethod,
    String qrStatus = 'not_applicable',
  }) async {
    final id = uuid.v4();
    final no = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final subtotal = items.fold<double>(0, (s, i) => s + (i['total'] as num).toDouble());
    final total = (subtotal - discount).clamp(0, double.infinity);
    final due = total - paid;
    final now = DateTime.now().toIso8601String();

    await db.db.transaction((txn) async {
      await txn.insert('invoices', {
        'id': id, 'invoice_no': no, 'customer_id': customerId,
        'subtotal': subtotal, 'discount': discount, 'tax': 0,
        'total': total, 'paid': paid, 'due': due,
        'payment_method': paymentMethod, 'status': due <= 0 ? 'PAID' : 'CREDIT', 'qr_status': qrStatus, 'created_at': now
      });
      for (final i in items) {
        await txn.insert('invoice_items', {
          'id': uuid.v4(), 'invoice_id': id, 'product_id': i['productId'],
          'product_name': i['name'], 'qty': i['qty'], 'price': i['price'],
          'discount': i['discount'] ?? 0, 'total': i['total']
        });
        await txn.rawUpdate('UPDATE products SET stock=stock-? WHERE id=?', [i['qty'], i['productId']]);
        await txn.insert('stock_movements', {
          'id': uuid.v4(), 'product_id': i['productId'], 'type': 'SALE',
          'qty': -i['qty'], 'unit_cost': i['price'], 'reference_id': id,
          'created_at': now
        });
      }
      if (customerId != null && due > 0) {
        await txn.rawUpdate('UPDATE customers SET balance=balance+? WHERE id=?', [due, customerId]);
        await txn.insert('ledger', {
          'id': uuid.v4(), 'customer_id': customerId, 'type': 'SALE_DUE',
          'amount': due, 'reference_id': id, 'note': no, 'created_at': now
        });
      }
    });
    await db.enqueueSync(entity: 'invoices', entityId: id, operation: 'upsert', payload: {'id': id, 'invoice_no': no, 'customer_id': customerId, 'subtotal': subtotal, 'discount': discount, 'total': total, 'paid': paid, 'due': due, 'payment_method': paymentMethod, 'status': due <= 0 ? 'PAID' : 'CREDIT', 'qr_status': qrStatus, 'items': items});
    await refresh();
  }

  String exportSnapshot() => jsonEncode({
    'customers': customers, 'products': products, 'farmers': farmers,
    'milk': milk, 'totals': totals
  });
}

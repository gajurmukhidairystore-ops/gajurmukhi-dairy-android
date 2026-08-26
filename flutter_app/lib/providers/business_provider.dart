import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';
import '../services/lucky_draw_service.dart';
import '../services/location_service.dart';
import '../services/mobile_cloud_service.dart';
import '../services/loan_calculator.dart';

class BusinessProvider extends ChangeNotifier {
  final AppDatabase db;
  final uuid = const Uuid();

  List<Map<String,Object?>> customers = [];
  List<Map<String,Object?>> products = [];
  List<Map<String,Object?>> farmers = [];
  List<Map<String,Object?>> milk = [];
  List<Map<String,Object?>> farmerPayments = [];
  List<Map<String,Object?>> loans = [];
  List<Map<String,Object?>> alarms = [];
  Map<String,num> totals = {};
  Map<String,num> financialSummary = {};
  List<Map<String,Object?>> luckyDraws = [];
  List<Map<String,Object?>> luckyDrawPrizes = [];
  List<Map<String,Object?>> luckyDrawTokens = [];
  List<Map<String,Object?>> luckyDrawWinners = [];
  List<Map<String,Object?>> orders = [];
  List<Map<String,Object?>> taxGroups = [];

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
    milk = await db.query('milk_collections', where: "collection_date=date('now','localtime')");
    farmerPayments = await db.query('farmer_payments', orderBy: 'created_at DESC');
    loans = await db.query('loans', where: 'active=1', orderBy: 'start_date DESC');
    alarms = await db.query('alarms', orderBy: 'due_at ASC');
    totals = await db.totals();
    financialSummary = await db.financialSummary();
    luckyDraws = await db.query('lucky_draws', orderBy: 'created_at DESC');
    luckyDrawPrizes = await db.query('lucky_draw_prizes', orderBy: 'prize_rank ASC');
    luckyDrawTokens = await db.query('lucky_draw_tokens', orderBy: 'created_at DESC');
    luckyDrawWinners = await db.query('lucky_draw_winners', orderBy: 'selected_at DESC');
    orders = await db.query('orders', orderBy: 'created_at DESC');
    taxGroups = await db.query('tax_groups', where: 'active=1', orderBy: 'name ASC');
    notifyListeners();
  }

  Future<void> createAlarm({required String title, required String category, required DateTime dueAt, String notes = '', String repeatRule = 'ONCE', String priority = 'NORMAL', String targetRole = 'admin'}) async {
    if (title.trim().isEmpty) throw ArgumentError('Alarm title is required');
    if (!dueAt.isAfter(DateTime.now())) throw ArgumentError('Alarm time must be in the future');
    const repeats = {'ONCE', 'DAILY', 'WEEKLY'};
    if (!repeats.contains(repeatRule)) throw ArgumentError('Unsupported repeat rule');
    const priorities = {'LOW', 'NORMAL', 'HIGH'};
    if (!priorities.contains(priority)) throw ArgumentError('Unsupported priority');
    const roles = {'admin', 'shop', 'collector', 'customer', 'all'};
    if (!roles.contains(targetRole)) throw ArgumentError('Unsupported target role');
    final id = uuid.v4();
    final row = <String, dynamic>{'id': id, 'title': title.trim(), 'category': category, 'notes': notes.trim(), 'due_at': dueAt.toIso8601String(), 'repeat_rule': repeatRule, 'priority': priority, 'target_role': targetRole, 'enabled': 1, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('alarms', row);
    await db.enqueueSync(entity: 'alarms', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> updateAlarm(String id, {String? title, String? notes, DateTime? dueAt, String? repeatRule, String? priority, String? targetRole, bool? enabled}) async {
    if (title != null && title.trim().isEmpty) throw ArgumentError('Alarm title is required');
    if (dueAt != null && !dueAt.isAfter(DateTime.now())) throw ArgumentError('Alarm time must be in the future');
    final changes = <String, dynamic>{};
    if (title != null) changes['title'] = title.trim();
    if (notes != null) changes['notes'] = notes.trim();
    if (dueAt != null) changes['due_at'] = dueAt.toIso8601String();
    if (repeatRule != null) changes['repeat_rule'] = repeatRule;
    if (priority != null) changes['priority'] = priority;
    if (targetRole != null) changes['target_role'] = targetRole;
    if (enabled != null) changes['enabled'] = enabled ? 1 : 0;
    if (changes.isEmpty) return;
    final updated = await db.update('alarms', changes, id);
    if (updated == 0) throw StateError('Alarm was not found');
    final row = (await db.query('alarms', where: 'id=?', args: [id])).first;
    await db.enqueueSync(entity: 'alarms', entityId: id, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<void> completeAlarm(String id) async {
    await updateAlarm(id, enabled: false);
    final updated = await db.update('alarms', {'completed_at': DateTime.now().toIso8601String()}, id);
    if (updated == 0) throw StateError('Alarm was not found');
    final row = (await db.query('alarms', where: 'id=?', args: [id])).first;
    await db.enqueueSync(entity: 'alarms', entityId: id, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<void> snoozeAlarm(String id, Duration duration) async {
    if (duration.isNegative || duration == Duration.zero) throw ArgumentError('Snooze duration must be positive');
    final until = DateTime.now().add(duration);
    await updateAlarm(id, dueAt: until, enabled: true);
    final updated = await db.update('alarms', {'snoozed_until': until.toIso8601String()}, id);
    if (updated == 0) throw StateError('Alarm was not found');
    final row = (await db.query('alarms', where: 'id=?', args: [id])).first;
    await db.enqueueSync(entity: 'alarms', entityId: id, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  static void validateCustomerLocation({double? latitude, double? longitude}) {
    if ((latitude == null) != (longitude == null)) throw ArgumentError('Latitude and longitude must be captured together');
    if (latitude != null && (latitude < -90 || latitude > 90 || longitude! < -180 || longitude > 180)) {
      throw ArgumentError('Customer location coordinates are invalid');
    }
  }

  Future<void> addCustomer(String name, String phone, String address, {double milkRate = 0, double? latitude, double? longitude, double? locationAccuracy, DateTime? locationCapturedAt}) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required');
    validateCustomerLocation(latitude: latitude, longitude: longitude);
    final id = uuid.v4();
    final row = <String, Object?>{'id': id, 'name': name.trim(), 'phone': phone.trim(), 'address': address.trim(), 'milk_rate': milkRate < 0 ? 0 : milkRate, 'latitude': latitude, 'longitude': longitude, 'location_accuracy': locationAccuracy, 'location_captured_at': latitude == null ? null : (locationCapturedAt ?? DateTime.now()).toIso8601String(), 'created_at': DateTime.now().toIso8601String()};
    await db.insert('customers', row);
    await db.enqueueSync(entity: 'customers', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> updateCustomerLocation(String customerId, {required double latitude, required double longitude, double? accuracy}) async {
    validateCustomerLocation(latitude: latitude, longitude: longitude);
    final capturedAt = DateTime.now().toIso8601String();
    final row = <String, Object?>{'latitude': latitude, 'longitude': longitude, 'location_accuracy': accuracy, 'location_captured_at': capturedAt};
    final updated = await db.update('customers', row, customerId);
    if (updated == 0) throw StateError('Customer was not found');
    await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: {'id': customerId, ...row});
    await refresh();
  }

  Future<void> clearCustomerLocation(String customerId) async {
    final row = <String, Object?>{'latitude': null, 'longitude': null, 'location_accuracy': null, 'location_captured_at': null};
    final updated = await db.update('customers', row, customerId);
    if (updated == 0) throw StateError('Customer was not found');
    await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: {'id': customerId, ...row});
    await refresh();
  }

  Future<void> updateCustomerMilkRate(String customerId, double rate) async {
    if (rate < 0) throw ArgumentError('Fixed milk rate cannot be negative');
    final updated = await db.update('customers', {'milk_rate': rate}, customerId);
    if (updated == 0) throw StateError('Party was not found');
    final row = (await db.query('customers', where: 'id=?', args: [customerId])).first;
    await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: Map<String, dynamic>.from(row));
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

  Future<void> updateProduct(String productId, {required String name, required double salePrice, required String category, required String unit, required String barcode}) async {
    if (name.trim().isEmpty || salePrice < 0) throw ArgumentError('Enter a product name and a valid sale price');
    final updated = await db.update('products', {'name': name.trim(), 'sale_price': salePrice, 'category': category, 'unit': unit, 'barcode': barcode.trim()}, productId);
    if (updated == 0) throw StateError('Inventory item was not found');
    final row = (await db.query('products', where: 'id=?', args: [productId])).first;
    await db.enqueueSync(entity: 'products', entityId: productId, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<void> archiveProduct(String productId) async {
    final updated = await db.update('products', {'active': 0}, productId);
    if (updated == 0) throw StateError('Inventory item was not found');
    final row = (await db.query('products', where: 'id=?', args: [productId])).first;
    await db.enqueueSync(entity: 'products', entityId: productId, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<void> addFarmer(String name, String phone, String address, double rate) async {
    final id = uuid.v4();
    final row = {'id': id, 'name': name, 'phone': phone, 'address': address, 'rate_per_litre': rate, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('farmers', row);
    await db.enqueueSync(entity: 'farmers', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> updateFarmerRate(String farmerId, double rate) async {
    if (rate <= 0) throw ArgumentError('Farmer rate must be greater than zero');
    final updated = await db.update('farmers', {'rate_per_litre': rate}, farmerId);
    if (updated == 0) throw StateError('Farmer was not found');
    final row = (await db.query('farmers', where: 'id=?', args: [farmerId])).first;
    await db.enqueueSync(entity: 'farmers', entityId: farmerId, operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<double> farmerBalance(String farmerId) async {
    final collections = await db.query('milk_collections', where: 'farmer_id=?', args: [farmerId]);
    final payments = await db.query('farmer_payments', where: 'farmer_id=?', args: [farmerId]);
    final payable = collections.fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
    final paid = payments.fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
    return (payable - paid).clamp(0, double.infinity).toDouble();
  }

  Future<void> recordFarmerPayment({required String farmerId, required double amount, required String method, String note = ''}) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
    final balance = await farmerBalance(farmerId);
    if (amount > balance + 0.01) throw ArgumentError('Payment cannot exceed farmer payable balance of NPR ${balance.toStringAsFixed(2)}');
    final row = <String, Object?>{'id': uuid.v4(), 'farmer_id': farmerId, 'amount': amount, 'method': method, 'note': note, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('farmer_payments', row);
    await db.enqueueSync(entity: 'farmer_payments', entityId: '${row['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<void> addLoan({required String name, required String lender, required double principal, required double annualInterestRate, required DateTime startDate, String note = ''}) async {
    if (name.trim().isEmpty || lender.trim().isEmpty) throw ArgumentError('Loan name and lender are required');
    if (principal <= 0) throw ArgumentError('Opening principal must be greater than zero');
    if (annualInterestRate < 0) throw ArgumentError('Interest rate cannot be negative');
    final row = <String, Object?>{
      'id': uuid.v4(), 'name': name.trim(), 'lender': lender.trim(), 'principal': principal,
      'annual_interest_rate': annualInterestRate, 'interest_method': 'SIMPLE_DAILY_REDUCING',
      'start_date': startDate.toIso8601String(), 'active': 1, 'note': note.trim(), 'created_at': DateTime.now().toIso8601String(),
    };
    await db.insert('loans', row);
    await db.enqueueSync(entity: 'loans', entityId: '${row['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(row));
    await refresh();
  }

  Future<Map<String, dynamic>> loanSnapshot(String loanId, {DateTime? asOf}) async {
    final rows = await db.query('loans', where: 'id=?', args: [loanId]);
    if (rows.isEmpty) throw StateError('Loan account was not found');
    final payments = await db.query('loan_payments', where: 'loan_id=?', args: [loanId], orderBy: 'payment_date ASC');
    return LoanCalculator.snapshot(loan: rows.first, payments: payments, asOf: asOf);
  }

  Future<void> recordLoanPayment({required String loanId, required double amount, DateTime? paymentDate, String note = ''}) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
    final effectiveDate = paymentDate ?? DateTime.now();
    final snapshot = await loanSnapshot(loanId, asOf: effectiveDate);
    final remaining = (snapshot['remaining_total'] as num).toDouble();
    if (amount > remaining + 0.01) throw ArgumentError('Payment cannot exceed remaining loan balance of ${remaining.toStringAsFixed(2)}');
    final row = <String, Object?>{'id': uuid.v4(), 'loan_id': loanId, 'amount': amount, 'payment_date': effectiveDate.toIso8601String(), 'note': note.trim(), 'created_at': DateTime.now().toIso8601String()};
    await db.insert('loan_payments', row);
    await db.enqueueSync(entity: 'loan_payments', entityId: '${row['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(row));
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
    final movementId = uuid.v4();
    final row = {'id': id, 'farmer_id': farmerId, 'collection_date': now.toIso8601String().substring(0,10), 'shift': shift, 'litres': litres, 'fat': fat, 'snf': snf, 'rate': rate, 'amount': litres * rate, 'created_at': now.toIso8601String()};
    var milkProductRows = await db.query('products', where: 'active=1 AND name=?', args: ['Milk 1 Ltr']);
    final createdProduct = milkProductRows.isEmpty;
    final productId = createdProduct ? uuid.v4() : '${milkProductRows.first['id']}';
    final product = createdProduct
        ? <String, Object?>{'id': productId, 'name': 'Milk 1 Ltr', 'category': 'Dairy', 'unit': 'Litre', 'sale_price': rate, 'purchase_price': rate, 'stock': 0, 'low_stock': 5, 'barcode': '', 'active': 1}
        : milkProductRows.first;
    final movement = {'id': movementId, 'product_id': productId, 'type': 'MILK_COLLECTION_IN', 'qty': litres, 'unit_cost': rate, 'reference_id': id, 'note': 'Farmer milk collection', 'created_at': now.toIso8601String()};
    await db.db.transaction((txn) async {
      if (createdProduct) await txn.insert('products', product);
      await txn.insert('milk_collections', row);
      await txn.rawUpdate('UPDATE products SET stock=stock+? WHERE id=?', [litres, productId]);
      await txn.insert('stock_movements', movement);
    });
    final syncedProduct = (await db.query('products', where: 'id=?', args: [productId])).first;
    await db.enqueueSync(entity: 'products', entityId: productId, operation: 'upsert', payload: Map<String, dynamic>.from(syncedProduct));
    await db.enqueueSync(entity: 'milk_collections', entityId: id, operation: 'upsert', payload: row);
    await db.enqueueSync(entity: 'stock_movements', entityId: movementId, operation: 'upsert', payload: movement);
    await refresh();
  }

  Future<void> removeMilkCollection(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('Collection id is required');
    final rows = await db.query('stock_movements', where: 'reference_id=? AND type=?', args: [id, 'MILK_COLLECTION_IN']);
    final collection = await db.query('milk_collections', where: 'id=?', args: [id]);
    if (collection.isEmpty) throw StateError('Collection record was not found');
    final movement = rows.isEmpty ? null : rows.first;
    await db.db.transaction((txn) async {
      if (movement != null) {
        final qty = (movement['qty'] as num?)?.toDouble() ?? 0;
        await txn.rawUpdate('UPDATE products SET stock=MAX(0, stock-?) WHERE id=?', [qty, movement['product_id']]);
        await txn.insert('stock_movements', {'id': uuid.v4(), 'product_id': movement['product_id'], 'type': 'MILK_COLLECTION_REVERSAL', 'qty': -qty, 'unit_cost': movement['unit_cost'] ?? 0, 'reference_id': id, 'note': 'Removed farmer milk collection', 'created_at': DateTime.now().toIso8601String()});
      }
      await txn.delete('milk_collections', where: 'id=?', whereArgs: [id]);
    });
    await db.enqueueSync(entity: 'milk_collections', entityId: id, operation: 'delete', payload: {'id': id});
    await refresh();
  }

  Future<List<Map<String, Object?>>> customerLedger(String customerId) async {
    return db.query('ledger', where: 'customer_id=?', args: [customerId]);
  }

  Future<void> recordAdvance(String? customerId, double amount, String method, String note) async {
    if (amount <= 0) throw ArgumentError('Advance amount must be greater than zero');
    final now = DateTime.now().toIso8601String();
    final id = uuid.v4();
    final advance = <String, Object?>{'id': id, 'customer_id': customerId, 'amount': amount, 'method': method, 'note': note, 'created_at': now};
    await db.insert('advances', advance);
    await db.enqueueSync(entity: 'advances', entityId: id, operation: 'upsert', payload: Map<String, dynamic>.from(advance));
    if (customerId != null) {
      await db.db.rawUpdate('UPDATE customers SET balance=balance-? WHERE id=?', [amount, customerId]);
      final ledger = <String, Object?>{'id': uuid.v4(), 'customer_id': customerId, 'type': 'ADVANCE', 'amount': amount, 'reference_id': id, 'note': note, 'created_at': now};
      await db.insert('ledger', ledger);
      await db.enqueueSync(entity: 'ledger', entityId: '${ledger['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(ledger));
      final customer = (await db.query('customers', where: 'id=?', args: [customerId])).first;
      await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: Map<String, dynamic>.from(customer));
    }
    await refresh();
  }

  Future<void> recordPayment(String? customerId, double amount, String method, String note) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
    final now = DateTime.now().toIso8601String();
    final id = uuid.v4();
    final payment = <String, Object?>{'id': id, 'customer_id': customerId, 'amount': amount, 'method': method, 'note': note, 'created_at': now};
    await db.insert('payments', payment);
    await db.enqueueSync(entity: 'payments', entityId: id, operation: 'upsert', payload: Map<String, dynamic>.from(payment));
    if (customerId != null) {
      await db.db.rawUpdate('UPDATE customers SET balance=balance-? WHERE id=?', [amount, customerId]);
      final ledger = <String, Object?>{'id': uuid.v4(), 'customer_id': customerId, 'type': 'PAYMENT', 'amount': amount, 'reference_id': id, 'note': note, 'created_at': now};
      await db.insert('ledger', ledger);
      await db.enqueueSync(entity: 'ledger', entityId: '${ledger['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(ledger));
      final customer = (await db.query('customers', where: 'id=?', args: [customerId])).first;
      await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: Map<String, dynamic>.from(customer));
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

  static double calculateTax({required double subtotal, required double discount, required double ratePercent}) {
    final taxable = (subtotal - discount).clamp(0, double.infinity).toDouble();
    return taxable * ratePercent.clamp(0, 100) / 100;
  }

  static bool arePaymentSplitsBalanced({required double total, required List<Map<String, dynamic>> splits}) {
    if (splits.isEmpty || total < 0) return false;
    final sum = splits.fold<double>(0, (value, split) => value + ((split['amount'] as num?)?.toDouble() ?? 0));
    return (sum - total).abs() < 0.01 && splits.every((split) => '${split['method'] ?? ''}'.trim().isNotEmpty && ((split['amount'] as num?)?.toDouble() ?? 0) > 0);
  }

  Future<void> addTaxGroup({required String name, required double rate}) async {
    if (name.trim().isEmpty) throw ArgumentError('Tax group name is required');
    if (rate < 0 || rate > 100) throw ArgumentError('Tax rate must be between 0 and 100 percent');
    final id = uuid.v4();
    final row = {'id': id, 'name': name.trim(), 'rate': rate, 'active': 1, 'created_at': DateTime.now().toIso8601String()};
    await db.insert('tax_groups', row);
    await db.enqueueSync(entity: 'tax_groups', entityId: id, operation: 'upsert', payload: row);
    await refresh();
  }

  Future<void> archiveTaxGroup(String id) async {
    final updated = await db.update('tax_groups', {'active': 0}, id);
    if (updated == 0) throw StateError('Tax group was not found');
    await db.enqueueSync(entity: 'tax_groups', entityId: id, operation: 'upsert', payload: {'id': id, 'active': 0});
    await refresh();
  }

  Future<void> createInvoice({
    String? customerId,
    required List<Map<String,dynamic>> items,
    required double discount,
    String discountReason = '',
    required double paid,
    required String paymentMethod,
    String qrStatus = 'not_applicable',
    double taxRate = 0,
    List<Map<String, dynamic>> paymentSplits = const [],
  }) async {
    final id = uuid.v4();
    final no = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final subtotal = items.fold<double>(0, (s, i) => s + (i['total'] as num).toDouble());
    final tax = calculateTax(subtotal: subtotal, discount: discount, ratePercent: taxRate);
    final total = ((subtotal - discount).clamp(0, double.infinity) + tax).toDouble();
    if (discount < 0 || discount > subtotal) throw ArgumentError('Discount must be between zero and the subtotal');
    if (discount > 0 && discountReason.trim().isEmpty) throw ArgumentError('Enter the discount reason or occasion for this bill');
    if (paymentMethod == 'SPLIT' && !arePaymentSplitsBalanced(total: paid, splits: paymentSplits)) throw ArgumentError('Split payment tenders must add up to the invoice total paid');
    if (paid < 0 || paid > total) throw ArgumentError('Paid amount must be between zero and the invoice total');
    final due = (total - paid).clamp(0, double.infinity).toDouble();
    final now = DateTime.now().toIso8601String();

    await db.db.transaction((txn) async {
      await txn.insert('invoices', {
        'id': id, 'invoice_no': no, 'customer_id': customerId,
        'subtotal': subtotal, 'discount': discount, 'discount_reason': discountReason.trim(), 'tax': tax, 'tax_rate': taxRate, 'total': total, 'paid': paid, 'due': due,
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
      if (paymentSplits.isNotEmpty) {
        for (final split in paymentSplits) {
          await txn.insert('payment_splits', {'id': uuid.v4(), 'invoice_id': id, 'method': split['method'], 'amount': split['amount'], 'reference': split['reference'], 'created_at': now});
        }
      }
      if (customerId != null && due > 0) {
        await txn.rawUpdate('UPDATE customers SET balance=balance+? WHERE id=?', [due, customerId]);
        await txn.insert('ledger', {
          'id': uuid.v4(), 'customer_id': customerId, 'type': 'SALE_DUE',
          'amount': due, 'reference_id': id, 'note': no, 'created_at': now
        });
      }
    });
    final invoice = <String, dynamic>{'id': id, 'invoice_no': no, 'customer_id': customerId, 'subtotal': subtotal, 'discount': discount, 'discount_reason': discountReason.trim(), 'tax': tax, 'tax_rate': taxRate, 'total': total, 'paid': paid, 'due': due, 'payment_method': paymentMethod, 'status': due <= 0 ? 'PAID' : 'CREDIT', 'qr_status': qrStatus, 'created_at': now};
    await db.enqueueSync(entity: 'invoices', entityId: id, operation: 'upsert', payload: invoice);
    for (final item in await db.query('invoice_items', where: 'invoice_id=?', args: [id])) {
      await db.enqueueSync(entity: 'invoice_items', entityId: '${item['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(item));
    }
    for (final movement in await db.query('stock_movements', where: 'reference_id=?', args: [id])) {
      await db.enqueueSync(entity: 'stock_movements', entityId: '${movement['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(movement));
    }
    for (final split in await db.query('payment_splits', where: 'invoice_id=?', args: [id])) {
      await db.enqueueSync(entity: 'payment_splits', entityId: '${split['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(split));
    }
    if (customerId != null) {
      final customer = (await db.query('customers', where: 'id=?', args: [customerId])).first;
      await db.enqueueSync(entity: 'customers', entityId: customerId, operation: 'upsert', payload: Map<String, dynamic>.from(customer));
      for (final ledger in await db.query('ledger', where: 'reference_id=?', args: [id])) {
        await db.enqueueSync(entity: 'ledger', entityId: '${ledger['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(ledger));
      }
    }
    for (final item in items) {
      final product = (await db.query('products', where: 'id=?', args: ['${item['productId']}'])).first;
      await db.enqueueSync(entity: 'products', entityId: '${product['id']}', operation: 'upsert', payload: Map<String, dynamic>.from(product));
    }
    await refresh();
  }

  Future<String> createLuckyDraw({
    required String monthKey,
    required String monthLabel,
    required String announcement,
    required DateTime drawDate,
    required List<Map<String, String>> prizes,
    String? createdBy,
  }) async {
    if (monthKey.trim().isEmpty || monthLabel.trim().isEmpty) throw ArgumentError('Month is required');
    if (prizes.length != 3) throw ArgumentError('Configure exactly three prizes');
    final existing = await db.query('lucky_draws', where: 'month_key=?', args: [monthKey.trim()]);
    if (existing.isNotEmpty) throw StateError('A lucky draw already exists for this month');
    final drawId = uuid.v4();
    final now = DateTime.now().toIso8601String();
    final draw = {
      'id': drawId, 'month_key': monthKey.trim(), 'month_label': monthLabel.trim(),
      'minimum_purchase': LuckyDrawService.minimumPurchase, 'announcement': announcement.trim(),
      'draw_date': drawDate.toIso8601String(), 'status': 'OPEN', 'created_by': createdBy, 'created_at': now,
    };
    await db.insert('lucky_draws', draw);
    await db.enqueueSync(entity: 'lucky_draws', entityId: drawId, operation: 'upsert', payload: draw);
    for (var i = 0; i < prizes.length; i++) {
      final prizeId = uuid.v4();
      final row = {'id': prizeId, 'draw_id': drawId, 'prize_rank': i + 1, 'prize_title': prizes[i]['title']!.trim(), 'prize_description': prizes[i]['description']!.trim(), 'prize_value': (prizes[i]['value'] ?? '').toString().trim(), 'active': 1};
      await db.insert('lucky_draw_prizes', row);
      await db.enqueueSync(entity: 'lucky_draw_prizes', entityId: prizeId, operation: 'upsert', payload: row);
    }
    await refresh();
    return drawId;
  }

  static void validateLuckyTokenRegistration({required double purchaseTotal, required String customerName, required String identityReference, required bool consented}) {
    if (!LuckyDrawService.isEligiblePurchase(purchaseTotal)) throw ArgumentError('A purchase of NPR 1,000 or more is required');
    if (customerName.trim().isEmpty) throw ArgumentError('Customer name is required');
    if (identityReference.trim().isEmpty) throw ArgumentError('Identity photo or document reference is required');
    if (!consented) throw ArgumentError('Customer consent is required before storing identity information');
  }

  static bool canReadLuckyDrawIdentity(String role) => LuckyDrawService.canAccessIdentityRecords(role);

  static bool canDeleteLuckyDrawIdentity(String role) => LuckyDrawService.canDeleteIdentityRecord(role);

  Future<String> issueLuckyToken({
    required String drawId,
    required double purchaseTotal,
    required String customerName,
    String? customerId,
    String? invoiceId,
    required String identityReference,
    required String identityType,
    required bool consented,
    required String issuedBy,
    String? tokenNumber,
  }) async {
    validateLuckyTokenRegistration(purchaseTotal: purchaseTotal, customerName: customerName, identityReference: identityReference, consented: consented);
    final drawRows = await db.query('lucky_draws', where: 'id=? AND status=?', args: [drawId, 'OPEN']);
    if (drawRows.isEmpty) throw StateError('This lucky draw is not open');
    final id = uuid.v4();
    final token = tokenNumber?.trim().isNotEmpty == true ? tokenNumber!.trim() : 'GJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final duplicate = await db.query('lucky_draw_tokens', where: 'draw_id=? AND token_number=?', args: [drawId, token]);
    if (LuckyDrawService.isDuplicateToken(duplicate.map((row) => '${row['token_number']}'), token)) throw StateError('Token number already exists for this draw');
    final now = DateTime.now();
    final row = {
      'id': id, 'draw_id': drawId, 'token_number': token, 'invoice_id': invoiceId, 'customer_id': customerId,
      'customer_name': customerName.trim(), 'identity_reference': null, 'identity_type': identityType.trim(),
      'consented': 1, 'issued_by': issuedBy, 'status': 'ELIGIBLE', 'created_at': now.toIso8601String(),
    };
    await db.insert('lucky_draw_tokens', row);
    final identityId = uuid.v4();
    final identityRow = {'id': identityId, 'token_id': id, 'identity_type': identityType.trim(), 'private_reference': identityReference.trim(), 'consented': 1, 'retention_until': now.add(const Duration(days: 365)).toIso8601String(), 'created_at': now.toIso8601String(), 'deleted_at': null};
    await db.insert('lucky_draw_identity_records', identityRow);
    await db.enqueueSync(entity: 'lucky_draw_tokens', entityId: id, operation: 'upsert', payload: row);
    await db.enqueueSync(entity: 'lucky_draw_identity_records', entityId: identityId, operation: 'upsert', payload: {...identityRow, 'private_reference': '[restricted]'});
    await refresh();
    return token;
  }

  Future<List<Map<String, Object?>>> privateLuckyDrawIdentityRecords(String role) async {
    if (!canReadLuckyDrawIdentity(role)) throw StateError('Only Admin or Store staff can access identity records');
    return db.query('lucky_draw_identity_records', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
  }

  Future<void> deleteLuckyDrawIdentityRecord(String role, String id) async {
    if (!canDeleteLuckyDrawIdentity(role)) throw StateError('Only Admin can delete identity records');
    await db.update('lucky_draw_identity_records', {'deleted_at': DateTime.now().toIso8601String(), 'private_reference': '[deleted]'}, id);
    await db.enqueueSync(entity: 'lucky_draw_identity_records', entityId: id, operation: 'delete', payload: {'id': id});
    await refresh();
  }

  Future<String> runLuckyDraw({required String drawId, int seed = 20260816}) async {
    final draws = await db.query('lucky_draws', where: 'id=?', args: [drawId]);
    if (draws.isEmpty) throw StateError('Lucky draw not found');
    if ('${draws.first['status']}' != 'OPEN') throw StateError('This draw has already been completed');
    final drawDate = DateTime.tryParse('${draws.first['draw_date']}');
    if (drawDate != null && DateTime.now().isBefore(drawDate)) throw StateError('The monthly draw can be generated on or after ${draws.first['draw_date']}');
    final prizes = await db.query('lucky_draw_prizes', where: 'draw_id=? AND active=1', args: [drawId]);
    final tokens = await db.query('lucky_draw_tokens', where: 'draw_id=? AND status=?', args: [drawId, 'ELIGIBLE']);
    final winners = LuckyDrawService.selectWinners(eligibleTokens: tokens, prizes: prizes, seed: seed);
    if (winners.length < prizes.length) throw StateError('At least three eligible tokens are required for three prizes');
    final now = DateTime.now().toIso8601String();
    final winnerRows = <Map<String, Object?>>[];
    await db.db.transaction((txn) async {
      for (final winner in winners) {
        final prize = prizes.firstWhere((p) => '${p['prize_rank']}' == '${winner['prize_rank']}');
        final token = tokens.firstWhere((t) => '${t['token_number']}' == '${winner['token_number']}');
        final winnerId = uuid.v4();
        final row = {'id': winnerId, 'draw_id': drawId, 'prize_id': prize['id'], 'token_id': token['id'], 'token_number': token['token_number'], 'masked_name': winner['masked_name'], 'selected_at': now};
        await txn.insert('lucky_draw_winners', row);
        winnerRows.add(row);
        await txn.update('lucky_draw_tokens', {'status': 'WON'}, where: 'id=?', whereArgs: [token['id']]);
      }
      for (final token in tokens) {
        if (!winners.any((winner) => '${winner['token_number']}' == '${token['token_number']}')) {
          await txn.update('lucky_draw_tokens', {'status': 'NOT_SELECTED'}, where: 'id=?', whereArgs: [token['id']]);
        }
      }
      await txn.update('lucky_draws', {'status': 'PUBLISHED', 'published_at': now}, where: 'id=?', whereArgs: [drawId]);
    });
    for (final row in winnerRows) {
      await db.enqueueSync(entity: 'lucky_draw_winners', entityId: '${row['id']}', operation: 'upsert', payload: row);
    }
    await refresh();
    final draw = draws.first;
    return LuckyDrawService.announcement(monthLabel: '${draw['month_label']}', message: '${draw['announcement']}', winners: winners.map((winner) => {...winner}).toList());
  }

  static const nearCustomerThresholdMeters = 1000.0;
  static const defaultArrivalRadiusMeters = 100.0;

  static int trackingIntervalForDistance(double? distanceMeters) => distanceMeters != null && distanceMeters <= nearCustomerThresholdMeters ? 15 : 30;

  static bool isArrivalEligible({required double distanceMeters, double radiusMeters = defaultArrivalRadiusMeters}) => distanceMeters >= 0 && distanceMeters <= radiusMeters;

  Future<Map<String, Object?>> createOrder({required String customerName, String phone = '', String? customerId, required String itemsJson, required double total, DateTime? deliveryAt, DateTime? reminderAt, bool reminderEnabled = true, String note = '', int? routePosition}) async {
    if (customerName.trim().isEmpty || total <= 0) throw ArgumentError('Customer name and a positive order total are required.');
    final id = uuid.v4();
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('orders', orderBy: 'route_position DESC');
    final nextPosition = existing.isEmpty ? 1 : ((existing.first['route_position'] as num?)?.toInt() ?? existing.length) + 1;
    final position = routePosition == null || routePosition < 1 ? nextPosition : routePosition;
    final row = <String, Object?>{'id': id, 'order_no': 'ORD-${DateTime.now().millisecondsSinceEpoch}', 'customer_id': customerId, 'customer_name': customerName.trim(), 'phone': phone.trim(), 'items_json': itemsJson, 'total': total, 'status': 'PENDING', 'order_at': now, 'delivery_at': deliveryAt?.toIso8601String(), 'reminder_at': reminderAt?.toIso8601String(), 'reminder_enabled': reminderEnabled ? 1 : 0, 'note': note.trim(), 'created_at': now, 'tracking_interval_seconds': 30, 'arrival_radius_meters': defaultArrivalRadiusMeters, 'call_unlocked': 0, 'route_position': position, 'delivery_result': 'PENDING'};
    await db.insert('orders', row);
    await db.enqueueSync(entity: 'orders', entityId: id, operation: 'upsert', payload: row);
    await refresh();
    return row;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    const allowed = {'PENDING', 'CONFIRMED', 'OUT_FOR_DELIVERY', 'DELIVERY_ATTEMPTED', 'DELIVERED', 'CANCELLED'};
    if (!allowed.contains(status)) throw ArgumentError('Unsupported order status.');
    final updated = await db.update('orders', {'status': status}, orderId);
    if (updated == 0) throw StateError('Order was not found');
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, 'status': status});
    await refresh();
  }

  Future<void> updateRoutePosition(String orderId, int position) async {
    if (position < 1) throw ArgumentError('Route stop must be 1 or higher');
    final updated = await db.update('orders', {'route_position': position}, orderId);
    if (updated == 0) throw StateError('Order was not found');
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, 'route_position': position});
    await refresh();
  }

  Future<void> recordDeliveryOutcome({required String orderId, required bool delivered, String missingGoodsNote = ''}) async {
    if (!delivered && missingGoodsNote.trim().isEmpty) throw ArgumentError('Enter the missing goods or delivery reason before saving');
    final result = delivered ? 'DELIVERED' : 'NOT_DELIVERED';
    final status = delivered ? 'DELIVERED' : 'DELIVERY_ATTEMPTED';
    final row = <String, Object?>{'status': status, 'delivery_result': result, 'missing_goods_note': delivered ? null : missingGoodsNote.trim(), 'handover_at': DateTime.now().toIso8601String()};
    final updated = await db.update('orders', row, orderId);
    if (updated == 0) throw StateError('Order was not found');
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...row});
    await refresh();
  }

  Future<void> assignDeliveryAgent({required String orderId, required String agentId, required String agentName, required String agentPhone}) async {
    if (agentId.trim().isEmpty || agentName.trim().isEmpty) throw ArgumentError('Delivery agent name and ID are required');
    final rows = await db.query('orders', where: 'id=?', args: [orderId]);
    if (rows.isEmpty) throw StateError('Order was not found');
    final order = rows.first;
    double? latitude = (order['destination_latitude'] as num?)?.toDouble();
    double? longitude = (order['destination_longitude'] as num?)?.toDouble();
    final customerId = '${order['customer_id'] ?? ''}'.trim();
    if ((latitude == null || longitude == null) && customerId.isNotEmpty) {
      final customers = await db.query('customers', where: 'id=?', args: [customerId]);
      if (customers.isNotEmpty) {
        latitude = (customers.first['latitude'] as num?)?.toDouble();
        longitude = (customers.first['longitude'] as num?)?.toDouble();
      }
    }
    if (latitude == null || longitude == null) throw StateError('Capture the customer GPS location before assigning delivery');
    final row = <String, Object?>{'delivery_agent_id': agentId.trim(), 'delivery_agent_name': agentName.trim(), 'delivery_agent_phone': agentPhone.trim(), 'destination_latitude': latitude, 'destination_longitude': longitude, 'tracking_interval_seconds': 30, 'arrival_radius_meters': defaultArrivalRadiusMeters, 'call_unlocked': 0, 'call_unlocked_at': null, 'call_attempted_at': null};
    await db.update('orders', row, orderId);
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...row});
    await refresh();
  }

  Future<Map<String, Object?>> createSecureTrackingLink({required String orderId, int expiresInMinutes = 180}) async {
    final rows = await db.query('orders', where: 'id=?', args: [orderId]);
    if (rows.isEmpty) throw StateError('Order was not found');
    final order = rows.first;
    final response = await MobileCloudService().createTrackingLink(deliveryLabel: '${order['order_no'] ?? orderId} · ${order['customer_name'] ?? 'Delivery'}', orderId: orderId, customerName: '${order['customer_name'] ?? ''}', customerPhone: '${order['phone'] ?? ''}', expiresInMinutes: expiresInMinutes);
    final sessionId = '${response['id'] ?? ''}'; final path = '${response['path'] ?? ''}'; final url = path.startsWith('http') ? path : '${MobileCloudService.baseUrl}$path';
    if (sessionId.isEmpty || path.isEmpty) throw StateError('Cloud returned an invalid tracking link');
    final changes = <String, Object?>{'tracking_session_id': sessionId, 'tracking_url': url, 'tracking_status': 'ACTIVE', 'tracking_expires_at': '${response['expiresAt'] ?? ''}', 'tracking_blocked': 0, 'tracking_last_cloud_update': DateTime.now().toIso8601String()};
    await db.update('orders', changes, orderId); await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...changes}); await refresh();
    return {...order, ...changes};
  }
  Future<void> setSecureTrackingStatus({required String orderId, required String status}) async {
    const allowed = {'ACTIVE', 'PAUSED', 'ENDED', 'BLOCKED'}; if (!allowed.contains(status)) throw ArgumentError('Unsupported tracking status');
    final rows = await db.query('orders', where: 'id=?', args: [orderId]); if (rows.isEmpty) throw StateError('Order was not found');
    final order = rows.first; final sessionId = '${order['tracking_session_id'] ?? ''}'.trim(); if (sessionId.isEmpty) throw StateError('Create a secure tracking link first');
    await MobileCloudService().updateTrackingStatus(id: sessionId, status: status.toLowerCase());
    final changes = <String, Object?>{'tracking_status': status, 'tracking_blocked': status == 'BLOCKED' ? 1 : 0, 'tracking_last_cloud_update': DateTime.now().toIso8601String()};
    await db.update('orders', changes, orderId); await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...changes}); await refresh();
  }
  Future<void> unassignDeliveryAgent(String orderId) async {
    final row = <String, Object?>{'delivery_agent_id': null, 'delivery_agent_name': null, 'delivery_agent_phone': null, 'last_driver_latitude': null, 'last_driver_longitude': null, 'last_driver_accuracy': null, 'last_driver_at': null, 'driver_distance_meters': null, 'call_unlocked': 0, 'call_unlocked_at': null, 'call_attempted_at': null};
    final updated = await db.update('orders', row, orderId);
    if (updated == 0) throw StateError('Order was not found');
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...row});
    await refresh();
  }

  Future<Map<String, Object?>> recordDriverLocation({required String orderId, required String agentId, required double latitude, required double longitude, double? accuracy}) async {
    validateCustomerLocation(latitude: latitude, longitude: longitude);
    final rows = await db.query('orders', where: 'id=?', args: [orderId]);
    if (rows.isEmpty) throw StateError('Order was not found');
    final order = rows.first;
    if ('${order['delivery_agent_id'] ?? ''}' != agentId) throw StateError('This order is not assigned to this delivery agent');
    final destinationLatitude = (order['destination_latitude'] as num?)?.toDouble();
    final destinationLongitude = (order['destination_longitude'] as num?)?.toDouble();
    if (destinationLatitude == null || destinationLongitude == null) throw StateError('Order has no customer destination');
    final distance = distanceMetersBetween(fromLatitude: latitude, fromLongitude: longitude, toLatitude: destinationLatitude, toLongitude: destinationLongitude);
    final radius = (order['arrival_radius_meters'] as num?)?.toDouble() ?? defaultArrivalRadiusMeters;
    final alreadyUnlocked = order['call_unlocked'] == 1;
    final eligible = alreadyUnlocked || isArrivalEligible(distanceMeters: distance, radiusMeters: radius);
    final now = DateTime.now().toIso8601String();
    final row = <String, Object?>{'last_driver_latitude': latitude, 'last_driver_longitude': longitude, 'last_driver_accuracy': accuracy, 'last_driver_at': now, 'driver_distance_meters': distance, 'tracking_interval_seconds': trackingIntervalForDistance(distance), 'call_unlocked': eligible ? 1 : 0, 'call_unlocked_at': alreadyUnlocked ? order['call_unlocked_at'] : (eligible ? now : null)};
    await db.update('orders', row, orderId);
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, ...row});
    await refresh();
    return {...order, ...row};
  }

  Future<void> markDeliveryCallAttempted(String orderId) async {
    final rows = await db.query('orders', where: 'id=?', args: [orderId]);
    if (rows.isEmpty) throw StateError('Order was not found');
    if (rows.first['call_unlocked'] != 1) throw StateError('Call unlocks only after the driver is within 100 metres of the customer');
    final at = DateTime.now().toIso8601String();
    await db.update('orders', {'call_attempted_at': at}, orderId);
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, 'call_attempted_at': at});
    await refresh();
  }

  Future<String> exportBackup() => db.exportJson();

  Future<void> restoreBackup(String source) async {
    await db.importJson(source);
    await refresh();
  }

  String exportSnapshot() => jsonEncode({
    'customers': customers, 'products': products, 'farmers': farmers,
    'milk': milk, 'orders': orders, 'totals': totals
  });
}

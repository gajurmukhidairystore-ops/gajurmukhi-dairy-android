import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';
import '../services/lucky_draw_service.dart';
import '../services/location_service.dart';

class BusinessProvider extends ChangeNotifier {
  final AppDatabase db;
  final uuid = const Uuid();

  List<Map<String,Object?>> customers = [];
  List<Map<String,Object?>> products = [];
  List<Map<String,Object?>> farmers = [];
  List<Map<String,Object?>> milk = [];
  Map<String,num> totals = {};
  List<Map<String,Object?>> luckyDraws = [];
  List<Map<String,Object?>> luckyDrawPrizes = [];
  List<Map<String,Object?>> luckyDrawTokens = [];
  List<Map<String,Object?>> luckyDrawWinners = [];
  List<Map<String,Object?>> orders = [];

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
    totals = await db.totals();
    luckyDraws = await db.query('lucky_draws', orderBy: 'created_at DESC');
    luckyDrawPrizes = await db.query('lucky_draw_prizes', orderBy: 'prize_rank ASC');
    luckyDrawTokens = await db.query('lucky_draw_tokens', orderBy: 'created_at DESC');
    luckyDrawWinners = await db.query('lucky_draw_winners', orderBy: 'selected_at DESC');
    orders = await db.query('orders', orderBy: 'created_at DESC');
    notifyListeners();
  }

  static void validateCustomerLocation({double? latitude, double? longitude}) {
    if ((latitude == null) != (longitude == null)) throw ArgumentError('Latitude and longitude must be captured together');
    if (latitude != null && (latitude < -90 || latitude > 90 || longitude! < -180 || longitude > 180)) {
      throw ArgumentError('Customer location coordinates are invalid');
    }
  }

  Future<void> addCustomer(String name, String phone, String address, {double? latitude, double? longitude, double? locationAccuracy, DateTime? locationCapturedAt}) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required');
    validateCustomerLocation(latitude: latitude, longitude: longitude);
    final id = uuid.v4();
    final row = <String, Object?>{'id': id, 'name': name.trim(), 'phone': phone.trim(), 'address': address.trim(), 'latitude': latitude, 'longitude': longitude, 'location_accuracy': locationAccuracy, 'location_captured_at': latitude == null ? null : (locationCapturedAt ?? DateTime.now()).toIso8601String(), 'created_at': DateTime.now().toIso8601String()};
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
      final row = {'id': prizeId, 'draw_id': drawId, 'prize_rank': i + 1, 'prize_title': prizes[i]['title']!.trim(), 'prize_description': prizes[i]['description']!.trim(), 'active': 1};
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

  Future<Map<String, Object?>> createOrder({required String customerName, String phone = '', String? customerId, required String itemsJson, required double total, DateTime? deliveryAt, DateTime? reminderAt, bool reminderEnabled = true, String note = ''}) async {
    if (customerName.trim().isEmpty || total <= 0) throw ArgumentError('Customer name and a positive order total are required.');
    final id = uuid.v4();
    final now = DateTime.now().toIso8601String();
    final row = <String, Object?>{'id': id, 'order_no': 'ORD-${DateTime.now().millisecondsSinceEpoch}', 'customer_id': customerId, 'customer_name': customerName.trim(), 'phone': phone.trim(), 'items_json': itemsJson, 'total': total, 'status': 'PENDING', 'order_at': now, 'delivery_at': deliveryAt?.toIso8601String(), 'reminder_at': reminderAt?.toIso8601String(), 'reminder_enabled': reminderEnabled ? 1 : 0, 'note': note.trim(), 'created_at': now, 'tracking_interval_seconds': 30, 'arrival_radius_meters': defaultArrivalRadiusMeters, 'call_unlocked': 0};
    await db.insert('orders', row);
    await db.enqueueSync(entity: 'orders', entityId: id, operation: 'upsert', payload: row);
    await refresh();
    return row;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    const allowed = {'PENDING', 'CONFIRMED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'};
    if (!allowed.contains(status)) throw ArgumentError('Unsupported order status.');
    final updated = await db.update('orders', {'status': status}, orderId);
    if (updated == 0) throw StateError('Order was not found');
    await db.enqueueSync(entity: 'orders', entityId: orderId, operation: 'upsert', payload: {'id': orderId, 'status': status});
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

  String exportSnapshot() => jsonEncode({
    'customers': customers, 'products': products, 'farmers': farmers,
    'milk': milk, 'orders': orders, 'totals': totals
  });
}

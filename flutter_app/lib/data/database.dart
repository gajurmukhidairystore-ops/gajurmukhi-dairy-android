import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  late Database db;

  Future<void> init({String? path}) async {
    final p = path ?? join(await getDatabasesPath(), 'gajurmukhi_pro.db');
    db = await openDatabase(p, version: 18, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
        latitude REAL, longitude REAL, location_accuracy REAL, location_captured_at TEXT,
        credit_limit REAL DEFAULT 0, balance REAL DEFAULT 0, milk_rate REAL DEFAULT 0,
        active INTEGER DEFAULT 1, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT, unit TEXT NOT NULL,
        sale_price REAL NOT NULL, purchase_price REAL DEFAULT 0, stock REAL DEFAULT 0,
        low_stock REAL DEFAULT 5, barcode TEXT, sku TEXT, size TEXT, color TEXT, variant_group TEXT, tax_group_id TEXT, active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices(
        id TEXT PRIMARY KEY, invoice_no TEXT UNIQUE NOT NULL, customer_id TEXT,
        subtotal REAL NOT NULL, discount REAL DEFAULT 0, tax REAL DEFAULT 0,
        total REAL NOT NULL, paid REAL DEFAULT 0, due REAL DEFAULT 0,
        tax_rate REAL DEFAULT 0, payment_method TEXT, status TEXT DEFAULT 'PAID', qr_status TEXT DEFAULT 'not_applicable', discount_reason TEXT, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE invoice_items(
        id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL, product_id TEXT NOT NULL,
        product_name TEXT NOT NULL, qty REAL NOT NULL, price REAL NOT NULL,
        discount REAL DEFAULT 0, total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ledger(
        id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, type TEXT NOT NULL,
        amount REAL NOT NULL, reference_id TEXT, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY, customer_id TEXT, amount REAL NOT NULL,
        method TEXT NOT NULL, reference TEXT, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE advances(
        id TEXT PRIMARY KEY, customer_id TEXT, amount REAL NOT NULL,
        method TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses(
        id TEXT PRIMARY KEY, category TEXT NOT NULL, amount REAL NOT NULL,
        method TEXT, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE farmers(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
        rate_per_litre REAL DEFAULT 0, active INTEGER DEFAULT 1, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
CREATE TABLE milk_collections(
        id TEXT PRIMARY KEY, farmer_id TEXT NOT NULL, collection_date TEXT NOT NULL,
        shift TEXT NOT NULL, litres REAL NOT NULL, fat REAL, snf REAL,
        rate REAL NOT NULL, amount REAL NOT NULL, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE farmer_payments(
        id TEXT PRIMARY KEY, farmer_id TEXT NOT NULL, amount REAL NOT NULL,
        method TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE loans(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, lender TEXT NOT NULL,
        principal REAL NOT NULL, annual_interest_rate REAL NOT NULL DEFAULT 0,
        interest_method TEXT NOT NULL DEFAULT 'SIMPLE_DAILY_REDUCING',
        start_date TEXT NOT NULL, active INTEGER DEFAULT 1, note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE loan_payments(
        id TEXT PRIMARY KEY, loan_id TEXT NOT NULL, amount REAL NOT NULL,
        payment_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements(
        id TEXT PRIMARY KEY, product_id TEXT NOT NULL, type TEXT NOT NULL,
        qty REAL NOT NULL, unit_cost REAL DEFAULT 0, reference_id TEXT,
        note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE returns(
        id TEXT PRIMARY KEY, type TEXT NOT NULL, product_id TEXT NOT NULL,
        qty REAL NOT NULL, amount REAL NOT NULL, party_id TEXT,
        reference_id TEXT, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE credit_reminders(
        id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, amount REAL NOT NULL,
        channel TEXT NOT NULL, message TEXT, status TEXT DEFAULT 'PENDING',
        created_at TEXT NOT NULL, sent_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE alarms(
        id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL,
        notes TEXT, due_at TEXT NOT NULL, repeat_rule TEXT NOT NULL DEFAULT 'ONCE',
        priority TEXT NOT NULL DEFAULT 'NORMAL', target_role TEXT NOT NULL DEFAULT 'admin',
        enabled INTEGER DEFAULT 1, completed_at TEXT, snoozed_until TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lucky_draws(
        id TEXT PRIMARY KEY, month_key TEXT NOT NULL, month_label TEXT NOT NULL,
        minimum_purchase REAL NOT NULL DEFAULT 1000, announcement TEXT NOT NULL,
        draw_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'OPEN',
        created_by TEXT, created_at TEXT NOT NULL, published_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE lucky_draw_prizes(
        id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, prize_rank INTEGER NOT NULL,
        prize_title TEXT NOT NULL, prize_description TEXT NOT NULL, prize_value TEXT, active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE lucky_draw_tokens(
        id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, token_number TEXT NOT NULL,
        invoice_id TEXT, customer_id TEXT, customer_name TEXT NOT NULL,
        identity_reference TEXT, identity_type TEXT, consented INTEGER NOT NULL DEFAULT 0,
        issued_by TEXT, status TEXT NOT NULL DEFAULT 'ELIGIBLE', created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lucky_draw_winners(
        id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, prize_id TEXT NOT NULL,
        token_id TEXT NOT NULL, token_number TEXT NOT NULL, masked_name TEXT NOT NULL,
        selected_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tax_groups(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, rate REAL NOT NULL DEFAULT 0,
        active INTEGER DEFAULT 1, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_splits(
        id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL, method TEXT NOT NULL,
        amount REAL NOT NULL, reference TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE quotes(
        id TEXT PRIMARY KEY, quote_no TEXT UNIQUE NOT NULL, customer_id TEXT,
        subtotal REAL NOT NULL, discount REAL DEFAULT 0, tax REAL DEFAULT 0,
        total REAL NOT NULL, status TEXT DEFAULT 'DRAFT', note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE quote_items(
        id TEXT PRIMARY KEY, quote_id TEXT NOT NULL, product_id TEXT NOT NULL,
        product_name TEXT NOT NULL, qty REAL NOT NULL, price REAL NOT NULL,
        discount REAL DEFAULT 0, total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE orders(
        id TEXT PRIMARY KEY, order_no TEXT UNIQUE NOT NULL, customer_id TEXT,
        customer_name TEXT NOT NULL, phone TEXT, items_json TEXT NOT NULL,
        total REAL NOT NULL, status TEXT NOT NULL DEFAULT 'PENDING',
        order_at TEXT NOT NULL, delivery_at TEXT, reminder_at TEXT,
        reminder_enabled INTEGER DEFAULT 1, note TEXT, created_at TEXT NOT NULL,
        delivery_agent_id TEXT, delivery_agent_name TEXT, delivery_agent_phone TEXT,
        destination_latitude REAL, destination_longitude REAL,
        last_driver_latitude REAL, last_driver_longitude REAL, last_driver_accuracy REAL,
        last_driver_at TEXT, driver_distance_meters REAL, tracking_interval_seconds INTEGER DEFAULT 30,
        arrival_radius_meters REAL DEFAULT 100, call_unlocked INTEGER DEFAULT 0,
        call_unlocked_at TEXT, call_attempted_at TEXT,
        route_position INTEGER, delivery_result TEXT DEFAULT 'PENDING',
        missing_goods_note TEXT, handover_at TEXT,
        tracking_session_id TEXT, tracking_url TEXT, tracking_status TEXT DEFAULT 'NOT_STARTED', tracking_expires_at TEXT,
        tracking_blocked INTEGER DEFAULT 0, tracking_last_cloud_update TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE lucky_draw_identity_records(
        id TEXT PRIMARY KEY, token_id TEXT NOT NULL, identity_type TEXT NOT NULL,
        private_reference TEXT NOT NULL, consented INTEGER NOT NULL DEFAULT 0,
        retention_until TEXT, created_at TEXT NOT NULL, deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, username TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL, pin_hash TEXT, active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE audit_logs(
        id TEXT PRIMARY KEY, user_id TEXT, action TEXT NOT NULL,
        entity TEXT, entity_id TEXT, metadata TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_queue(
        id TEXT PRIMARY KEY, entity TEXT NOT NULL, entity_id TEXT NOT NULL,
        operation TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // Reserved for future schema migrations.
    }
    if (oldV < 3) {
      await db.execute("ALTER TABLE invoices ADD COLUMN qr_status TEXT DEFAULT 'not_applicable'");
    }
    if (oldV < 4) {
      await db.execute('''CREATE TABLE returns(id TEXT PRIMARY KEY, type TEXT NOT NULL, product_id TEXT NOT NULL, qty REAL NOT NULL, amount REAL NOT NULL, party_id TEXT, reference_id TEXT, note TEXT, created_at TEXT NOT NULL)''');
    }
    if (oldV < 5) {
      await db.execute('''CREATE TABLE credit_reminders(id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, amount REAL NOT NULL, channel TEXT NOT NULL, message TEXT, status TEXT DEFAULT 'PENDING', created_at TEXT NOT NULL, sent_at TEXT)''');
    }
    if (oldV < 6) {
      await db.execute('''CREATE TABLE lucky_draws(id TEXT PRIMARY KEY, month_key TEXT NOT NULL, month_label TEXT NOT NULL, minimum_purchase REAL NOT NULL DEFAULT 1000, announcement TEXT NOT NULL, draw_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'OPEN', created_by TEXT, created_at TEXT NOT NULL, published_at TEXT)''');
      await db.execute('''CREATE TABLE lucky_draw_prizes(id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, prize_rank INTEGER NOT NULL, prize_title TEXT NOT NULL, prize_description TEXT NOT NULL, prize_value TEXT, active INTEGER DEFAULT 1)''');
      await db.execute('''CREATE TABLE lucky_draw_tokens(id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, token_number TEXT NOT NULL, invoice_id TEXT, customer_id TEXT, customer_name TEXT NOT NULL, identity_reference TEXT, identity_type TEXT, consented INTEGER NOT NULL DEFAULT 0, issued_by TEXT, status TEXT NOT NULL DEFAULT 'ELIGIBLE', created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE lucky_draw_winners(id TEXT PRIMARY KEY, draw_id TEXT NOT NULL, prize_id TEXT NOT NULL, token_id TEXT NOT NULL, token_number TEXT NOT NULL, masked_name TEXT NOT NULL, selected_at TEXT NOT NULL)''');
    }
    if (oldV < 7) {
      await db.execute('''CREATE TABLE lucky_draw_identity_records(id TEXT PRIMARY KEY, token_id TEXT NOT NULL, identity_type TEXT NOT NULL, private_reference TEXT NOT NULL, consented INTEGER NOT NULL DEFAULT 0, retention_until TEXT, created_at TEXT NOT NULL, deleted_at TEXT)''');
    }
    if (oldV < 8) {
      await db.execute('ALTER TABLE products ADD COLUMN sku TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN size TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN color TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN variant_group TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN tax_group_id TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN tax_rate REAL DEFAULT 0');
      await db.execute('''CREATE TABLE tax_groups(id TEXT PRIMARY KEY, name TEXT NOT NULL, rate REAL NOT NULL DEFAULT 0, active INTEGER DEFAULT 1, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE payment_splits(id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL, method TEXT NOT NULL, amount REAL NOT NULL, reference TEXT, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE quotes(id TEXT PRIMARY KEY, quote_no TEXT UNIQUE NOT NULL, customer_id TEXT, subtotal REAL NOT NULL, discount REAL DEFAULT 0, tax REAL DEFAULT 0, total REAL NOT NULL, status TEXT DEFAULT 'DRAFT', note TEXT, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE quote_items(id TEXT PRIMARY KEY, quote_id TEXT NOT NULL, product_id TEXT NOT NULL, product_name TEXT NOT NULL, qty REAL NOT NULL, price REAL NOT NULL, discount REAL DEFAULT 0, total REAL NOT NULL)''');
    }
    if (oldV < 9) {
      await db.execute('''CREATE TABLE orders(id TEXT PRIMARY KEY, order_no TEXT UNIQUE NOT NULL, customer_id TEXT, customer_name TEXT NOT NULL, phone TEXT, items_json TEXT NOT NULL, total REAL NOT NULL, status TEXT NOT NULL DEFAULT 'PENDING', order_at TEXT NOT NULL, delivery_at TEXT, reminder_at TEXT, reminder_enabled INTEGER DEFAULT 1, note TEXT, created_at TEXT NOT NULL)''');
    }
    if (oldV < 10) {
      await db.execute('ALTER TABLE customers ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE customers ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE customers ADD COLUMN location_accuracy REAL');
      await db.execute('ALTER TABLE customers ADD COLUMN location_captured_at TEXT');
    }
    if (oldV < 11) {
      await db.execute('ALTER TABLE orders ADD COLUMN delivery_agent_id TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN delivery_agent_name TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN delivery_agent_phone TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN destination_latitude REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN destination_longitude REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN last_driver_latitude REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN last_driver_longitude REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN last_driver_accuracy REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN last_driver_at TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN driver_distance_meters REAL');
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_interval_seconds INTEGER DEFAULT 30');
      await db.execute('ALTER TABLE orders ADD COLUMN arrival_radius_meters REAL DEFAULT 100');
      await db.execute('ALTER TABLE orders ADD COLUMN call_unlocked INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN call_unlocked_at TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN call_attempted_at TEXT');
    }
    if (oldV < 12) {
      await db.execute('ALTER TABLE lucky_draw_prizes ADD COLUMN prize_value TEXT');
    }
    if (oldV < 13) {
      await db.execute('ALTER TABLE customers ADD COLUMN milk_rate REAL DEFAULT 0');
      await db.execute('''CREATE TABLE farmer_payments(id TEXT PRIMARY KEY, farmer_id TEXT NOT NULL, amount REAL NOT NULL, method TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL)''');
    }
    if (oldV < 14) {
      await db.execute('''CREATE TABLE loans(id TEXT PRIMARY KEY, name TEXT NOT NULL, lender TEXT NOT NULL, principal REAL NOT NULL, annual_interest_rate REAL NOT NULL DEFAULT 0, interest_method TEXT NOT NULL DEFAULT 'SIMPLE_DAILY_REDUCING', start_date TEXT NOT NULL, active INTEGER DEFAULT 1, note TEXT, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE loan_payments(id TEXT PRIMARY KEY, loan_id TEXT NOT NULL, amount REAL NOT NULL, payment_date TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL)''');
    }
    if (oldV < 15) {
      await db.execute('ALTER TABLE invoices ADD COLUMN discount_reason TEXT');
    }
    if (oldV < 16) {
      await db.execute('ALTER TABLE orders ADD COLUMN route_position INTEGER');
      await db.execute("ALTER TABLE orders ADD COLUMN delivery_result TEXT DEFAULT 'PENDING'");
      await db.execute('ALTER TABLE orders ADD COLUMN missing_goods_note TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN handover_at TEXT');
    }
    if (oldV < 17) {
      await db.execute('''CREATE TABLE alarms(id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, notes TEXT, due_at TEXT NOT NULL, repeat_rule TEXT NOT NULL DEFAULT 'ONCE', priority TEXT NOT NULL DEFAULT 'NORMAL', target_role TEXT NOT NULL DEFAULT 'admin', enabled INTEGER DEFAULT 1, completed_at TEXT, snoozed_until TEXT, created_at TEXT NOT NULL)''');
    }
    if (oldV < 18) {
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_session_id TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_url TEXT');
      await db.execute("ALTER TABLE orders ADD COLUMN tracking_status TEXT DEFAULT 'NOT_STARTED'");
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_expires_at TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_blocked INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE orders ADD COLUMN tracking_last_cloud_update TEXT');
    }
  }

  Future<List<Map<String,Object?>>> query(String table, {String? where, List<Object?>? args, String? orderBy}) =>
      db.query(table, where: where, whereArgs: args, orderBy: orderBy);

  Future<int> insert(String table, Map<String,Object?> row) => db.insert(table, row);
  Future<int> update(String table, Map<String,Object?> row, String id) =>
      db.update(table, row, where: 'id=?', whereArgs: [id]);

  Future<int> delete(String table, String id) =>
      db.delete(table, where: 'id=?', whereArgs: [id]);

  Future<void> enqueueSync({required String entity, required String entityId, required String operation, required Map<String, dynamic> payload}) async {
    await db.insert('sync_queue', {'id': '${DateTime.now().microsecondsSinceEpoch}-$entityId', 'entity': entity, 'entity_id': entityId, 'operation': operation, 'payload': jsonEncode(payload), 'created_at': DateTime.now().toIso8601String(), 'synced': 0});
  }

  Future<List<Map<String, Object?>>> pendingSync() => db.query('sync_queue', where: 'synced=0', orderBy: 'created_at ASC');
  Future<void> markSynced(String id) async => db.update('sync_queue', {'synced': 1}, where: 'id=?', whereArgs: [id]);

  static const syncableTables = {
    'customers', 'products', 'invoices', 'invoice_items', 'ledger', 'payments', 'advances', 'expenses', 'loans', 'loan_payments',
    'farmers', 'milk_collections', 'farmer_payments', 'stock_movements', 'returns', 'credit_reminders', 'lucky_draws',
    'lucky_draw_prizes', 'lucky_draw_tokens', 'lucky_draw_winners', 'tax_groups', 'payment_splits',
    'quotes', 'quote_items', 'orders', 'alarms',
  };

  Future<void> applyCloudRecord({required String entity, required String recordId, required String operation, required Map<String, dynamic> payload}) async {
    if (!syncableTables.contains(entity)) return;
    final localPending = await db.query('sync_queue', where: 'entity=? AND entity_id=? AND synced=0', whereArgs: [entity, recordId], limit: 1);
    if (localPending.isNotEmpty) return;
    if (operation == 'delete') {
      await delete(entity, recordId);
      return;
    }
    if (operation != 'upsert') return;
    final row = <String, Object?>{...payload};
    row['id'] = row['id'] ?? recordId;
    await db.insert(entity, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static const snapshotTables = [
    'customers', 'products', 'invoices', 'invoice_items', 'ledger', 'payments', 'advances', 'expenses', 'loans', 'loan_payments',
    'farmers', 'milk_collections', 'farmer_payments', 'stock_movements', 'returns', 'credit_reminders', 'lucky_draws',
    'lucky_draw_prizes', 'lucky_draw_tokens', 'lucky_draw_winners', 'lucky_draw_identity_records',
    'tax_groups', 'payment_splits', 'quotes', 'quote_items', 'orders', 'alarms', 'users', 'audit_logs', 'sync_queue',
  ];

  Future<String> exportJson() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in snapshotTables) {
      tables[table] = await db.query(table);
    }
    return jsonEncode({'format': 'gajurmukhi-offline-backup', 'schema_version': 18, 'exported_at': DateTime.now().toUtc().toIso8601String(), 'tables': tables});
  }

  Future<void> importJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['format'] != 'gajurmukhi-offline-backup' || decoded['tables'] is! Map) throw const FormatException('This file is not a supported Gajurmukhi backup');
    final rawTables = Map<Object?, Object?>.from(decoded['tables'] as Map);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in snapshotTables) {
      final rows = rawTables[table];
      if (rows == null) { tables[table] = []; continue; }
      if (rows is! List || rows.any((row) => row is! Map)) throw FormatException('Invalid rows in backup table $table');
      tables[table] = rows.map((row) => Map<String, Object?>.from(row as Map)).toList();
    }
    await db.transaction((txn) async {
      for (final table in snapshotTables.reversed) {
        await txn.delete(table);
      }
      for (final table in snapshotTables) {
        for (final row in tables[table]!) {
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<Map<String,num>> totals() async {
    final sales = await db.rawQuery("SELECT COALESCE(SUM(total),0) v FROM invoices WHERE date(created_at)=date('now','localtime')");
    final paid = await db.rawQuery("SELECT COALESCE(SUM(paid),0) v FROM invoices WHERE date(created_at)=date('now','localtime')");
    final expenses = await db.rawQuery("SELECT COALESCE(SUM(amount),0) v FROM expenses WHERE date(created_at)=date('now','localtime')");
    final milk = await db.rawQuery("SELECT COALESCE(SUM(litres),0) v FROM milk_collections WHERE collection_date=date('now','localtime')");
    final due = await db.rawQuery('SELECT COALESCE(SUM(CASE WHEN balance > 0 THEN balance ELSE 0 END),0) v FROM customers');
    return {
      'sales': sales.first['v'] as num,
      'collection': paid.first['v'] as num,
      'expenses': expenses.first['v'] as num,
      'milkLitres': milk.first['v'] as num,
      'due': due.first['v'] as num,
    };
  }

  Future<Map<String,num>> financialSummary() async {
    final farmerPayable = await db.rawQuery('SELECT COALESCE((SELECT SUM(amount) FROM milk_collections),0) - COALESCE((SELECT SUM(amount) FROM farmer_payments),0) v');
    final partyPayable = await db.rawQuery('SELECT COALESCE(SUM(CASE WHEN balance < 0 THEN -balance ELSE 0 END),0) v FROM customers');
    final customerReceivable = await db.rawQuery('SELECT COALESCE(SUM(CASE WHEN balance > 0 THEN balance ELSE 0 END),0) v FROM customers');
    final todayMilkPayable = await db.rawQuery("SELECT COALESCE(SUM(amount),0) v FROM milk_collections WHERE collection_date=date('now','localtime')");
    final todayFarmerPaid = await db.rawQuery("SELECT COALESCE(SUM(amount),0) v FROM farmer_payments WHERE date(created_at)=date('now','localtime')");
    final todayWalkInDue = await db.rawQuery("SELECT COALESCE(SUM(due),0) v FROM invoices WHERE customer_id IS NULL AND due > 0 AND date(created_at)=date('now','localtime')");
    final todayCustomerDue = await db.rawQuery("SELECT COALESCE(SUM(due),0) v FROM invoices WHERE customer_id IS NOT NULL AND due > 0 AND date(created_at)=date('now','localtime')");
    final todayPartyPaid = await db.rawQuery("SELECT COALESCE(SUM(amount),0) v FROM payments WHERE date(created_at)=date('now','localtime')");
    return {
      'farmerPayable': ((farmerPayable.first['v'] as num?) ?? 0).clamp(0, double.infinity),
      'partyPayable': partyPayable.first['v'] as num,
      'customerReceivable': customerReceivable.first['v'] as num,
      'todayMilkPayable': todayMilkPayable.first['v'] as num,
      'todayFarmerPaid': todayFarmerPaid.first['v'] as num,
      'todayWalkInDue': todayWalkInDue.first['v'] as num,
      'todayCustomerDue': todayCustomerDue.first['v'] as num,
      'todayPartyPaid': todayPartyPaid.first['v'] as num,
    };
  }
}

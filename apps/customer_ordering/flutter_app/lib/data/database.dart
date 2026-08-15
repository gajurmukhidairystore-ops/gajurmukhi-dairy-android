import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  late Database db;

  Future<void> init() async {
    final p = join(await getDatabasesPath(), 'gajurmukhi_pro.db');
    db = await openDatabase(p, version: 5, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
        credit_limit REAL DEFAULT 0, balance REAL DEFAULT 0,
        active INTEGER DEFAULT 1, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT, unit TEXT NOT NULL,
        sale_price REAL NOT NULL, purchase_price REAL DEFAULT 0, stock REAL DEFAULT 0,
        low_stock REAL DEFAULT 5, barcode TEXT, active INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices(
        id TEXT PRIMARY KEY, invoice_no TEXT UNIQUE NOT NULL, customer_id TEXT,
        subtotal REAL NOT NULL, discount REAL DEFAULT 0, tax REAL DEFAULT 0,
        total REAL NOT NULL, paid REAL DEFAULT 0, due REAL DEFAULT 0,
        payment_method TEXT, status TEXT DEFAULT 'PAID', qr_status TEXT DEFAULT 'not_applicable', note TEXT, created_at TEXT NOT NULL
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
  }

  Future<List<Map<String,Object?>>> query(String table, {String? where, List<Object?>? args}) =>
      db.query(table, where: where, whereArgs: args);

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

  Future<Map<String,num>> totals() async {
    final sales = await db.rawQuery('SELECT COALESCE(SUM(total),0) v FROM invoices WHERE date(created_at)=date("now","localtime")');
    final paid = await db.rawQuery('SELECT COALESCE(SUM(paid),0) v FROM invoices WHERE date(created_at)=date("now","localtime")');
    final expenses = await db.rawQuery('SELECT COALESCE(SUM(amount),0) v FROM expenses WHERE date(created_at)=date("now","localtime")');
    final milk = await db.rawQuery('SELECT COALESCE(SUM(litres),0) v FROM milk_collections WHERE collection_date=date("now","localtime")');
    final due = await db.rawQuery('SELECT COALESCE(SUM(balance),0) v FROM customers');
    return {
      'sales': sales.first['v'] as num,
      'collection': paid.first['v'] as num,
      'expenses': expenses.first['v'] as num,
      'milkLitres': milk.first['v'] as num,
      'due': due.first['v'] as num,
    };
  }
}

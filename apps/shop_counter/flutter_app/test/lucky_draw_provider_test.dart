import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gajurmukhi_dairy_business_pro/data/database.dart';
import 'package:gajurmukhi_dairy_business_pro/providers/business_provider.dart';
import 'package:gajurmukhi_dairy_business_pro/ui/screens/lucky_draw.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<(AppDatabase, BusinessProvider, String)> seededProvider() async {
    final db = AppDatabase();
    await db.init();
    final provider = BusinessProvider(db);
    await provider.bootstrap();
    final drawId = await provider.createLuckyDraw(
      monthKey: 'test-${DateTime.now().microsecondsSinceEpoch}',
      monthLabel: 'Test Monthly Draw',
      announcement: 'Thank you',
      drawDate: DateTime.now().subtract(const Duration(days: 1)),
      prizes: const [
        {'title': '1st Prize', 'description': 'Mixer'},
        {'title': '2nd Prize', 'description': 'Basket'},
        {'title': '3rd Prize', 'description': 'Voucher'},
      ],
      createdBy: 'admin',
    );
    return (db, provider, drawId);
  }

  test('BusinessProvider rejects a duplicate token and protects identity records by role', () async {
    final (db, provider, drawId) = await seededProvider();
    await provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/private/id-a.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-DUP');
    await expectLater(provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Bikash Thapa', identityReference: '/private/id-b.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-DUP'), throwsStateError);
    expect((await provider.privateLuckyDrawIdentityRecords('admin')), hasLength(1));
    expect((await provider.privateLuckyDrawIdentityRecords('shop')), hasLength(1));
    await expectLater(provider.privateLuckyDrawIdentityRecords('customer'), throwsStateError);
    final recordId = (await provider.privateLuckyDrawIdentityRecords('admin')).single['id'] as String;
    await expectLater(provider.deleteLuckyDrawIdentityRecord('shop', recordId), throwsStateError);
    await provider.deleteLuckyDrawIdentityRecord('admin', recordId);
    expect(await provider.privateLuckyDrawIdentityRecords('admin'), isEmpty);
    await db.db.close();
  });

  testWidgets('Customer lucky-draw screen shows draw details and token status lookup', (tester) async {
    final (db, provider, drawId) = await seededProvider();
    await provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/private/id-a.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-VIEW');
    await provider.refresh();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: provider, child: const MaterialApp(home: LuckyDrawScreen(role: 'customer'))));
    await tester.pumpAndSettle();
    expect(find.text('Test Monthly Draw · OPEN'), findsOneWidget);
    expect(find.textContaining('1st Prize'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'GJ-VIEW');
    await tester.tap(find.text('Check token status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Token GJ-VIEW'), findsOneWidget);
    await db.db.close();
  });
}

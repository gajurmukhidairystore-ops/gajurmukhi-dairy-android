import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gajurmukhi_dairy_business_pro/data/database.dart';
import 'package:gajurmukhi_dairy_business_pro/providers/business_provider.dart';
import 'package:gajurmukhi_dairy_business_pro/services/lucky_draw_service.dart';
import 'package:gajurmukhi_dairy_business_pro/ui/screens/lucky_draw.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<(AppDatabase, BusinessProvider, String)> seededProvider() async {
    final db = AppDatabase();
    await db.init(path: inMemoryDatabasePath);
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

  test('BusinessProvider rejects duplicate tokens and protects identity records', () async {
    final (db, provider, drawId) = await seededProvider();
    try {
      await provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/private/id-a.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-DUP');
      await expectLater(provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Bikash Thapa', identityReference: '/private/id-b.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-DUP'), throwsStateError);
      expect((await provider.privateLuckyDrawIdentityRecords('admin')), hasLength(1));
      expect((await provider.privateLuckyDrawIdentityRecords('shop')), hasLength(1));
      await expectLater(provider.privateLuckyDrawIdentityRecords('customer'), throwsStateError);
      final recordId = (await provider.privateLuckyDrawIdentityRecords('admin')).single['id'] as String;
      await expectLater(provider.deleteLuckyDrawIdentityRecord('shop', recordId), throwsStateError);
      await provider.deleteLuckyDrawIdentityRecord('admin', recordId);
      expect(await provider.privateLuckyDrawIdentityRecords('admin'), isEmpty);
    } finally {
      await db.db.close();
    }
  });

  test('provider validation, token lookup, and role rules are covered', () {
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 999, customerName: 'Asha Rai', identityReference: '/id.jpg', consented: true), throwsArgumentError);
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/id.jpg', consented: true), returnsNormally);
    expect(BusinessProvider.canReadLuckyDrawIdentity('customer'), isFalse);
    expect(BusinessProvider.canDeleteLuckyDrawIdentity('admin'), isTrue);
    final token = <String, Object?>{'token_number': 'GJ-VIEW', 'status': 'WON'};
    expect(LuckyDrawService.findTokenStatus([token], ' GJ-VIEW ')!['status'], 'WON');
  });

  testWidgets('customer screen renders draw details, token lookup, and public masked winner', (tester) async {
    final (db, provider, drawId) = await seededProvider();
    try {
      await provider.issueLuckyToken(drawId: drawId, purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/private/id-a.jpg', identityType: 'Citizenship', consented: true, issuedBy: 'shop', tokenNumber: 'GJ-VIEW');
      final draw = provider.luckyDraws.single;
      final prize = provider.luckyDrawPrizes.first;
      final token = provider.luckyDrawTokens.single;
      await db.insert('lucky_draw_winners', {'id': 'winner-1', 'draw_id': draw['id'], 'prize_id': prize['id'], 'token_id': token['id'], 'token_number': 'GJ-VIEW', 'masked_name': 'A*** R**', 'selected_at': DateTime.now().toIso8601String()});
      await db.update('lucky_draws', {'status': 'PUBLISHED'}, '${draw['id']}');
      await provider.refresh();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyDrawScreen(role: 'customer', providerOverride: provider))));
      await tester.pumpAndSettle();
      expect(find.text('Test Monthly Draw · PUBLISHED'), findsOneWidget);
      expect(find.textContaining('Draw date:'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Public winner: GJ-VIEW · A*** R**'), 300, scrollable: find.byType(ListView));
      expect(find.text('Public winner: GJ-VIEW · A*** R**'), findsOneWidget);
    } finally {
      await db.db.close();
    }
  });
}

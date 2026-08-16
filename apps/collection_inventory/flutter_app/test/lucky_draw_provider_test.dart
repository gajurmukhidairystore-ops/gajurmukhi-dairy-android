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
    const drawId = 'draw-integration';
    await db.insert('lucky_draws', {'id': drawId, 'month_key': 'integration', 'month_label': 'Integration Draw', 'minimum_purchase': 1000, 'announcement': 'Thank you', 'draw_date': DateTime(2026, 8, 1).toIso8601String(), 'status': 'OPEN', 'created_by': 'admin', 'created_at': DateTime(2026, 7, 1).toIso8601String()});
    for (var rank = 1; rank <= 3; rank++) {
      await db.insert('lucky_draw_prizes', {'id': 'prize-$rank', 'draw_id': drawId, 'prize_rank': rank, 'prize_title': '$rank Prize', 'prize_description': 'Prize $rank', 'active': 1});
    }
    await provider.refresh();
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
    final provider = BusinessProvider(AppDatabase());
    provider.luckyDraws = [{'id': 'draw-1', 'month_label': 'Test Monthly Draw', 'status': 'PUBLISHED', 'draw_date': '2026-08-31', 'announcement': 'Thank you'}];
    provider.luckyDrawPrizes = [{'id': 'p1', 'draw_id': 'draw-1', 'prize_rank': 1, 'prize_title': '1st Prize', 'prize_description': 'Mixer'}];
    provider.luckyDrawTokens = [{'id': 'token-1', 'draw_id': 'draw-1', 'token_number': 'GJ-VIEW', 'status': 'WON', 'customer_name': 'Asha Rai'}];
    provider.luckyDrawWinners = [{'id': 'winner-1', 'draw_id': 'draw-1', 'prize_id': 'p1', 'token_number': 'GJ-VIEW', 'masked_name': 'A*** R**'}];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyDrawScreen(role: 'customer', providerOverride: provider))));
    await tester.pumpAndSettle();
    expect(find.text('Test Monthly Draw · PUBLISHED'), findsOneWidget);
    expect(find.textContaining('Draw date:'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Public winner: GJ-VIEW · A*** R**'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Public winner: GJ-VIEW · A*** R**'), findsOneWidget);
  });
}

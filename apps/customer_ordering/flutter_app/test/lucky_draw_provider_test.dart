import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/data/database.dart';
import 'package:gajurmukhi_dairy_business_pro/providers/business_provider.dart';
import 'package:gajurmukhi_dairy_business_pro/ui/screens/lucky_draw.dart';

void main() {
  test('provider token validation enforces eligibility, identity, and consent', () {
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 999, customerName: 'Asha Rai', identityReference: '/id.jpg', consented: true), throwsArgumentError);
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 1000, customerName: '', identityReference: '/id.jpg', consented: true), throwsArgumentError);
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '', consented: true), throwsArgumentError);
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/id.jpg', consented: false), throwsArgumentError);
    expect(() => BusinessProvider.validateLuckyTokenRegistration(purchaseTotal: 1000, customerName: 'Asha Rai', identityReference: '/id.jpg', consented: true), returnsNormally);
  });

  test('provider identity access boundaries are role restricted', () {
    expect(BusinessProvider.canReadLuckyDrawIdentity('admin'), isTrue);
    expect(BusinessProvider.canReadLuckyDrawIdentity('shop'), isTrue);
    expect(BusinessProvider.canReadLuckyDrawIdentity('customer'), isFalse);
    expect(BusinessProvider.canDeleteLuckyDrawIdentity('admin'), isTrue);
    expect(BusinessProvider.canDeleteLuckyDrawIdentity('shop'), isFalse);
    expect(BusinessProvider.canDeleteLuckyDrawIdentity('customer'), isFalse);
  });

  testWidgets('customer screen shows token lookup, draw details, and masked published winner', (tester) async {
    final provider = BusinessProvider(AppDatabase());
    provider.luckyDraws = [
      {'id': 'draw-1', 'month_label': 'Test Monthly Draw', 'status': 'PUBLISHED', 'draw_date': '2026-08-31', 'announcement': 'Thank you'},
    ];
    provider.luckyDrawPrizes = [
      {'id': 'p1', 'draw_id': 'draw-1', 'prize_rank': 1, 'prize_title': '1st Prize', 'prize_description': 'Mixer'},
      {'id': 'p2', 'draw_id': 'draw-1', 'prize_rank': 2, 'prize_title': '2nd Prize', 'prize_description': 'Basket'},
      {'id': 'p3', 'draw_id': 'draw-1', 'prize_rank': 3, 'prize_title': '3rd Prize', 'prize_description': 'Voucher'},
    ];
    provider.luckyDrawTokens = [
      {'id': 'token-1', 'draw_id': 'draw-1', 'token_number': 'GJ-VIEW', 'status': 'WON', 'customer_name': 'Asha Rai'},
    ];
    provider.luckyDrawWinners = [
      {'id': 'winner-1', 'draw_id': 'draw-1', 'prize_id': 'p1', 'token_number': 'GJ-VIEW', 'masked_name': 'A*** R**'},
    ];
    await tester.pumpWidget(MaterialApp(home: LuckyDrawScreen(role: 'customer', providerOverride: provider)));
    await tester.pumpAndSettle();
    expect(find.text('Test Monthly Draw · PUBLISHED'), findsOneWidget);
    expect(find.textContaining('Draw date: 2026-08-31'), findsOneWidget);
    expect(find.textContaining('1st Prize'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('A*** R** · Public masked name only'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'GJ-VIEW');
    await tester.tap(find.text('Check token status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Token GJ-VIEW'), findsOneWidget);
  });
}

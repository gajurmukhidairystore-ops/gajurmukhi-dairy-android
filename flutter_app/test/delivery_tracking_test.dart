import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/providers/business_provider.dart';
import 'package:gajurmukhi_dairy_business_pro/services/location_service.dart';
import 'package:gajurmukhi_dairy_business_pro/services/role_permissions.dart';

void main() {
  test('tracking uses 30 seconds normally and 15 seconds within one kilometre', () {
    expect(BusinessProvider.trackingIntervalForDistance(null), 30);
    expect(BusinessProvider.trackingIntervalForDistance(1500), 30);
    expect(BusinessProvider.trackingIntervalForDistance(1000), 15);
    expect(trackingIntervalSecondsForDistance(999), 15);
  });

  test('tax calculation applies to the discounted taxable amount', () {
    expect(BusinessProvider.calculateTax(subtotal: 1000, discount: 100, ratePercent: 13), closeTo(117, 0.001));
    expect(BusinessProvider.calculateTax(subtotal: 1000, discount: 1200, ratePercent: 13), 0);
  });

  test('split tenders must be positive and balance to the paid amount', () {
    expect(BusinessProvider.arePaymentSplitsBalanced(total: 1000, splits: [{'method': 'CASH', 'amount': 600}, {'method': 'QR', 'amount': 400}]), isTrue);
    expect(BusinessProvider.arePaymentSplitsBalanced(total: 1000, splits: [{'method': 'CASH', 'amount': 600}, {'method': 'QR', 'amount': 399}]), isFalse);
    expect(BusinessProvider.arePaymentSplitsBalanced(total: 1000, splits: [{'method': 'CASH', 'amount': 1000}, {'method': 'QR', 'amount': 0}]), isFalse);
  });

  test('only the assigned Collector can transmit live GPS', () {
    expect(RolePermissions.canStartDeliveryTracking('collector'), isTrue);
    expect(RolePermissions.canStartDeliveryTracking('admin'), isFalse);
    expect(RolePermissions.canStartDeliveryTracking('shop'), isFalse);
  });

  test('arrival call gate is inclusive at 100 metres and rejects beyond radius', () {
    expect(BusinessProvider.isArrivalEligible(distanceMeters: 100), isTrue);
    expect(isWithinArrivalRadius(distanceMeters: 100), isTrue);
    expect(BusinessProvider.isArrivalEligible(distanceMeters: 100.01), isFalse);
    expect(BusinessProvider.isArrivalEligible(distanceMeters: -1), isFalse);
  });
}

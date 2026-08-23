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

import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/providers/business_provider.dart';

void main() {
  test('customer location requires latitude and longitude together', () {
    expect(() => BusinessProvider.validateCustomerLocation(latitude: 27.7172), throwsArgumentError);
    expect(() => BusinessProvider.validateCustomerLocation(longitude: 85.3240), throwsArgumentError);
  });

  test('customer location accepts valid coordinates and rejects out-of-range values', () {
    expect(() => BusinessProvider.validateCustomerLocation(latitude: 27.7172, longitude: 85.3240), returnsNormally);
    expect(() => BusinessProvider.validateCustomerLocation(latitude: 91, longitude: 85.3240), throwsArgumentError);
    expect(() => BusinessProvider.validateCustomerLocation(latitude: 27.7172, longitude: 181), throwsArgumentError);
  });
}

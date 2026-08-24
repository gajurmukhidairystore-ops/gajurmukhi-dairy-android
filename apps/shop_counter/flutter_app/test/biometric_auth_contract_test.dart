import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/local_auth_service.dart';

void main() {
  test('PIN hashing is deterministic and never equals the original PIN', () {
    const pin = '1234';
    final first = hashPinValue(pin);
    final second = hashPinValue(pin);

    expect(first, second);
    expect(first, isNot(pin));
    expect(first.length, 64);
  });

  test('LocalSession keeps role-scoped identity fields without a PIN', () {
    const session = LocalSession(id: 'id', name: 'Owner', username: 'admin', role: 'admin');
    expect(session.username, 'admin');
    expect(session.role, 'admin');
  });
}

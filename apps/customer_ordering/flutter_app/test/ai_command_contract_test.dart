import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/ai_command_service.dart';

void main() {
  test('AI command help documents safe settings commands', () async {
    final result = await AiCommandService().execute(command: 'help', role: 'admin');
    expect(result.message, contains('set theme to dark'));
    expect(result.message, contains('set low stock alert'));
    expect(result.changed, isFalse);
  });

  test('non-admin cannot change the default payment method', () async {
    final result = await AiCommandService().execute(command: 'set default payment to qr', role: 'shop');
    expect(result.message, contains('Only Admin'));
    expect(result.changed, isFalse);
    expect(result.requiresConfirmation, isFalse);
  });

  test('sensitive Admin setting requires explicit confirmation', () async {
    final result = await AiCommandService().execute(command: 'set low stock alert to 10', role: 'admin');
    expect(result.requiresConfirmation, isTrue);
    expect(result.confirmationToken, 'low_stock:10');
    expect(result.changed, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/order_notification_service.dart';

void main() {
  final now = DateTime(2026, 8, 23, 10);

  test('future reminder is allowed for an active order', () {
    expect(OrderNotificationService.canSchedule(status: 'PENDING', enabled: true, reminderAt: now.add(const Duration(minutes: 30)), now: now), isTrue);
  });

  test('disabled, past, delivered, and cancelled reminders are rejected', () {
    expect(OrderNotificationService.canSchedule(status: 'PENDING', enabled: false, reminderAt: now.add(const Duration(minutes: 30)), now: now), isFalse);
    expect(OrderNotificationService.canSchedule(status: 'PENDING', enabled: true, reminderAt: now.subtract(const Duration(minutes: 1)), now: now), isFalse);
    expect(OrderNotificationService.canSchedule(status: 'DELIVERED', enabled: true, reminderAt: now.add(const Duration(minutes: 30)), now: now), isFalse);
    expect(OrderNotificationService.canSchedule(status: 'CANCELLED', enabled: true, reminderAt: now.add(const Duration(minutes: 30)), now: now), isFalse);
  });
}

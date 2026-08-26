import 'package:flutter_test/flutter_test.dart';
import '../lib/services/alarm_service.dart';

void main() {
  test('alarm repeat rules map to Android calendar components', () {
    final at = DateTime(2026, 8, 26, 8, 30);
    expect(AlarmPlan(at, 'ONCE').dateComponents, isNull);
    expect(AlarmPlan(at, 'DAILY').dateComponents, DateTimeComponents.time);
    expect(AlarmPlan(at, 'WEEKLY').dateComponents, DateTimeComponents.dayOfWeekAndTime);
  });

  test('notification identifiers are stable, non-negative, and distinct for normal ids', () {
    expect(AlarmService.notificationId('alarm-1'), AlarmService.notificationId('alarm-1'));
    expect(AlarmService.notificationId('alarm-1'), greaterThanOrEqualTo(0));
    expect(AlarmService.notificationId('alarm-1'), isNot(AlarmService.notificationId('alarm-2')));
  });
}

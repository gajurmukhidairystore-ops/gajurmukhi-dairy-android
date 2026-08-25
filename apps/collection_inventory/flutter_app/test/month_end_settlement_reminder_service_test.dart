import 'package:bikram_sambat/bikram_sambat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/month_end_settlement_reminder_service.dart';

void main() {
  test('month-end reminder is scheduled on the final day of the current Nepali month', () {
    final now = DateTime(2026, 8, 25, 9);
    final plan = NepaliMonthEndReminderPlanner.next(now: now);
    final scheduled = plan.reminderAt.toBikramSambat();
    expect(plan.reminderAt.isAfter(now), isTrue);
    expect(scheduled.day, scheduled.daysInMonth);
    expect(plan.nepaliMonthKey, '${scheduled.year.toString().padLeft(4, '0')}-${scheduled.month.toString().padLeft(2, '0')}');
  });

  test('month-end reminder rolls to the next Nepali month after the current month closing time', () {
    final current = DateTime(2026, 8, 25).toBikramSambat();
    final afterClosing = BikramSambat(current.year, current.month, current.daysInMonth, 19).toDateTime();
    final plan = NepaliMonthEndReminderPlanner.next(now: afterClosing);
    final scheduled = plan.reminderAt.toBikramSambat();
    expect(plan.reminderAt.isAfter(afterClosing), isTrue);
    expect(scheduled.day, scheduled.daysInMonth);
    expect(scheduled.month == current.month && scheduled.year == current.year, isFalse);
  });
}

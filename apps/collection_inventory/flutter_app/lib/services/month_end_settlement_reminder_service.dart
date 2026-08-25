import 'package:bikram_sambat/bikram_sambat.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NepaliMonthEndReminderPlan {
  final DateTime reminderAt;
  final String nepaliMonthKey;
  const NepaliMonthEndReminderPlan({required this.reminderAt, required this.nepaliMonthKey});
}

class NepaliMonthEndReminderPlanner {
  static NepaliMonthEndReminderPlan next({DateTime? now, int hour = 18}) {
    final source = now ?? DateTime.now();
    final current = source.toBikramSambat();
    var month = current;
    var reminder = BikramSambat(month.year, month.month, month.daysInMonth, hour).toDateTime();
    if (!reminder.isAfter(source)) {
      month = BikramSambat(current.year, current.month + 1);
      reminder = BikramSambat(month.year, month.month, month.daysInMonth, hour).toDateTime();
    }
    return NepaliMonthEndReminderPlan(
      reminderAt: reminder,
      nepaliMonthKey: '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
    );
  }
}

class MonthEndSettlementReminderService {
  static const _notificationId = 824010;
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> scheduleNext() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await plugin.initialize(settings);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    final plan = NepaliMonthEndReminderPlanner.next();
    await plugin.cancel(_notificationId);
    await plugin.zonedSchedule(
      _notificationId,
      'Nepali month-end settlement review',
      'Review money to collect from parties/customers and farmer payments still due before ${plan.nepaliMonthKey} closes.',
      tz.TZDateTime.from(plan.reminderAt, tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('gajurmukhi_month_end', 'Month-end settlement reminders', channelDescription: 'Nepali calendar reminders for customer receivables and farmer payables', importance: Importance.high, priority: Priority.high)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: plan.nepaliMonthKey,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

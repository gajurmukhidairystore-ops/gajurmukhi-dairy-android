import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmPlan {
  final DateTime dueAt;
  final String repeatRule;
  const AlarmPlan(this.dueAt, this.repeatRule);

  bool get isFuture => dueAt.isAfter(DateTime.now());

  DateTimeComponents? get dateComponents {
    switch (repeatRule) {
      case 'DAILY':
        return DateTimeComponents.time;
      case 'WEEKLY':
        return DateTimeComponents.dayOfWeekAndTime;
      default:
        return null;
    }
  }
}

class AlarmService {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await plugin.initialize(settings);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  static int notificationId(String id) => id.hashCode & 0x7fffffff;

  Future<void> schedule({required String id, required String title, required String body, required DateTime dueAt, String repeatRule = 'ONCE', String category = 'CUSTOM', bool enabled = true}) async {
    await cancel(id);
    if (!enabled || !dueAt.isAfter(DateTime.now())) return;
    final plan = AlarmPlan(dueAt, repeatRule);
    await plugin.zonedSchedule(
      notificationId(id),
      'Gajurmukhi reminder: $title',
      body,
      tz.TZDateTime.from(dueAt, tz.local),
      NotificationDetails(android: AndroidNotificationDetails('gajurmukhi_alarms', 'Business alarms', channelDescription: 'Payments, collections, deliveries, stock, and custom reminders', importance: Importance.high, priority: Priority.high, category: category == 'PAYMENT' ? AndroidNotificationCategory.reminder : AndroidNotificationCategory.event)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: plan.dateComponents,
      payload: id,
    );
  }

  Future<void> cancel(String id) => plugin.cancel(notificationId(id));
  Future<void> cancelAll() => plugin.cancelAll();
}

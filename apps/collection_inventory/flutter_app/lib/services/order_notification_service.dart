import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class OrderNotificationService {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  static bool canSchedule({required String status, required bool enabled, required DateTime reminderAt, DateTime? now}) {
    const terminalStatuses = {'DELIVERED', 'CANCELLED'};
    return enabled && !terminalStatuses.contains(status) && reminderAt.isAfter(now ?? DateTime.now());
  }

  Future<void> scheduleOrderReminder({required String orderId, required String customerName, required DateTime reminderAt, required String orderSummary, String status = 'PENDING', bool enabled = true}) async {
    if (!canSchedule(status: status, enabled: enabled, reminderAt: reminderAt)) return;
    final scheduled = tz.TZDateTime.from(reminderAt, tz.local);
    await plugin.zonedSchedule(
      orderId.hashCode,
      'Order reminder: $customerName',
      orderSummary,
      scheduled,
      const NotificationDetails(android: AndroidNotificationDetails('gajurmukhi_orders', 'Order reminders', channelDescription: 'Reminders for pending customer orders', importance: Importance.high, priority: Priority.high)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: orderId,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelOrderReminder(String orderId) => plugin.cancel(orderId.hashCode);

  Future<void> cancelAll() => plugin.cancelAll();
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:your_creative_notebook/models/event.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    
    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleEventReminder(Event event) async {
    if (event.reminder == null || event.startDate.isBefore(DateTime.now())) {
      return;
    }

    final notificationTime = event.startDate.subtract(Duration(minutes: event.reminder!));
    
    if (notificationTime.isBefore(DateTime.now())) {
      return;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        event.id.hashCode, // Use event ID as notification ID
        event.title,
        event.description ?? 'Event reminder',
        tz.TZDateTime.from(notificationTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'Event Reminders',
            channelDescription: 'Notifications for event reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Scheduled reminder for event ${event.id} at $notificationTime');
    } catch (e) {
      print('Error scheduling reminder: $e');
      throw Exception('Failed to schedule reminder: $e');
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    try {
      await _notificationsPlugin.cancel(eventId.hashCode);
      print('Canceled reminder for event $eventId');
    } catch (e) {
      print('Error canceling reminder: $e');
      throw Exception('Failed to cancel reminder: $e');
    }
  }

  Future<void> rescheduleAllEventReminders(List<Event> events) async {
    try {
      // Cancel all existing reminders
      await _notificationsPlugin.cancelAll();
      print('Canceled all existing reminders');

      // Schedule new reminders for all events
      for (final event in events) {
        await scheduleEventReminder(event);
      }
      print('Rescheduled reminders for ${events.length} events');
    } catch (e) {
      print('Error rescheduling reminders: $e');
      throw Exception('Failed to reschedule reminders: $e');
    }
  }
}
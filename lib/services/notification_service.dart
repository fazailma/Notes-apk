import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:your_creative_notebook/models/notification_item.dart';
import 'package:your_creative_notebook/models/event.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final PocketbaseService _pbService = PocketbaseService();
  
  List<NotificationItem> _notifications = [];
  bool _isInitialized = false;

  // Getters
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Request permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Load saved notifications
      await _loadNotifications();
      
      // Schedule pending event reminders
      await _scheduleEventReminders();
      
      _isInitialized = true;
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        print('Notification permission denied');
      }
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      if (result != true) {
        print('iOS notification permission denied');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final notificationId = data['notificationId'] as String?;
        
        if (notificationId != null) {
          markAsRead(notificationId);
        }
        
        // Handle navigation based on notification type
        final type = data['type'] as String?;
        final eventId = data['eventId'] as String?;
        
        // TODO: Implement navigation logic
        // NavigationService.navigateToEvent(eventId);
        
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications') ?? [];
      
      _notifications = notificationsJson
          .map((json) => NotificationItem.fromJson(jsonDecode(json)))
          .toList();
      
      // Sort by timestamp (newest first)
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Loaded ${_notifications.length} notifications');
    } catch (e) {
      print('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _notifications
          .map((notification) => jsonEncode(notification.toJson()))
          .toList();
      
      await prefs.setStringList('notifications', notificationsJson);
      print('Saved ${_notifications.length} notifications');
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  Future<void> addNotification(NotificationItem notification) async {
    _notifications.insert(0, notification);
    
    // Keep only last 100 notifications
    if (_notifications.length > 100) {
      _notifications = _notifications.take(100).toList();
    }
    
    await _saveNotifications();
    print('Added notification: ${notification.title}');
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      print('Marked notification as read: $notificationId');
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _saveNotifications();
    print('Marked all notifications as read');
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    
    // Cancel scheduled notification if exists
    await _cancelScheduledNotification(notificationId);
    print('Deleted notification: $notificationId');
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    
    // Cancel all scheduled notifications
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('Cleared all notifications');
  }

  // Event reminder specific methods
  Future<void> scheduleEventReminder(Event event) async {
    if (event.reminder == null || event.reminder == 0) {
      return; // No reminder set
    }

    try {
      final reminderTime = event.startDate.subtract(Duration(minutes: event.reminder!));
    
      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        print('Reminder time is in the past, skipping: ${event.title}');
        return;
      }

      final notificationId = event.id.hashCode;
    
      // PERBAIKAN: Gunakan data event yang sebenarnya
      String notificationTitle = event.title;
      String notificationBody = event.description ?? 'Acara akan segera dimulai';
    
      // Tambahkan info waktu reminder
      if (event.reminder! > 0) {
        String reminderText = _getReminderText(event.reminder!);
        notificationBody = '${event.description ?? event.title} - akan dimulai dalam $reminderText';
      }
    
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        notificationTitle, // Gunakan judul event yang sebenarnya
        notificationBody,  // Gunakan deskripsi event yang sebenarnya
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'Event Reminders',
            channelDescription: 'Notifications for upcoming events',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({
          'type': 'eventReminder',
          'eventId': event.id,
          'notificationId': 'event_${event.id}',
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('Scheduled reminder for event: ${event.title} at $reminderTime');
    } catch (e) {
      print('Error scheduling event reminder: $e');
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    try {
      final notificationId = eventId.hashCode;
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      print('Cancelled reminder for event: $eventId');
    } catch (e) {
      print('Error cancelling event reminder: $e');
    }
  }

  Future<void> _cancelScheduledNotification(String notificationId) async {
    try {
      final id = notificationId.hashCode;
      await _flutterLocalNotificationsPlugin.cancel(id);
    } catch (e) {
      print('Error cancelling scheduled notification: $e');
    }
  }

  Future<void> _scheduleEventReminders() async {
    try {
      if (!_pbService.isLoggedIn) return;
      
      final events = await _pbService.getEvents();
      
      for (final eventData in events) {
        final event = Event.fromJson(eventData.toJson());
        await scheduleEventReminder(event);
      }
      
      print('Scheduled reminders for ${events.length} events');
    } catch (e) {
      print('Error scheduling event reminders: $e');
    }
  }

  // Create notification for immediate display
  Future<void> createEventReminderNotification(Event event) async {
    final reminderText = event.reminder != null ? _getReminderText(event.reminder!) : 'sekarang';
  
    final notification = NotificationItem(
      id: 'event_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Pengingat: ${event.title}',
      content: event.allDay 
          ? 'Acara "${event.title}" hari ini'
          : 'Acara "${event.title}" akan dimulai dalam $reminderText',
      timestamp: DateTime.now(),
      isRead: false,
      type: NotificationType.eventReminder,
      eventId: event.id,
      data: {
        'eventTitle': event.title,
        'eventStartDate': event.startDate.toIso8601String(),
        'reminderMinutes': event.reminder,
        'location': event.location,
      },
    );

    await addNotification(notification);
  }

  // Helper methods
  String _getReminderText(int minutes) {
    if (minutes == 0) return 'sekarang';
    if (minutes < 60) return '$minutes menit';
    if (minutes < 1440) return '${minutes ~/ 60} jam';
    return '${minutes ~/ 1440} hari';
  }

  // Test notification (for debugging)
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Pengingat Acara Test',
      'Meeting dengan tim design akan dimulai dalam 15 menit',
      platformChannelSpecifics,
    );

    // Also add to in-app notifications
    final testNotification = NotificationItem(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Pengingat Acara Test',
      content: 'Meeting dengan tim design akan dimulai dalam 15 menit',
      timestamp: DateTime.now(),
      isRead: false,
      type: NotificationType.eventReminder,
    );

    await addNotification(testNotification);
  }

  // Refresh event reminders (call this when events are updated)
  Future<void> refreshEventReminders() async {
    try {
      // Cancel all existing event reminders
      await _flutterLocalNotificationsPlugin.cancelAll();
      
      // Reschedule all event reminders
      await _scheduleEventReminders();
      
      print('Refreshed all event reminders');
    } catch (e) {
      print('Error refreshing event reminders: $e');
    }
  }
}

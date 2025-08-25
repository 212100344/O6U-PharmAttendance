// lib/utils/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await requestExactAlarmPermission();
  }

  Future<void> requestExactAlarmPermission() async {
    var status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) {
      print("Exact alarm permission granted");
    } else if (status.isDenied) {
      var result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) {
        print("Exact alarm permission granted after request");
      } else {
        if (result.isPermanentlyDenied) {
          openAppSettings();
        } else {
          print("Exact alarm permission denied: $status");
        }
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else if (status.isRestricted) {
      print("Exact alarm permission restricted");
    } else if (status.isLimited) {
      print("Exact alarm permission limited");
    } else {
      print("Unknown permission status: $status");
    }
  }


  Future<void> showNotification(int id, String title, String body) async {
    var androidDetails = const AndroidNotificationDetails(
      'approval_notifications',
      'Account Approval Notifications',
      channelDescription: 'Notifications for account approvals and round enrollments', // Updated description
      importance: Importance.max,
      priority: Priority.high,
    );
    var iOSDetails = const DarwinNotificationDetails();
    var platformDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    tz.setLocalLocation(tz.local);

    final now = tz.TZDateTime.now(tz.local);
    final scheduleTime = now.add(const Duration(seconds: 1));

    print("------------------------------------");
    print("showNotification called at: ${DateTime.now()} (System Time)");
    print("Notification ID: $id");
    print("Title: $title");
    print("Body: $body");
    print("Scheduled Time (tz.local): $scheduleTime");
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduleTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("Notification scheduled successfully.");
    } catch (e) {
      print("ERROR SCHEDULING NOTIFICATION: $e");
    }
    print("------------------------------------");
  }

  // Use a generic key format for setting the "sent" flag, but keep track of type
  Future<void> setNotificationSentFlag(String notificationKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationKey, true);
  }

  Future<bool> hasNotificationBeenSent(String notificationKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationKey) ?? false;
  }

  // Save notifications using a consistent key format (notifications_studentId)
  Future<void> saveNotification(
      String studentId, String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationKey = 'notifications_$studentId'; // Consistent key
    final now = DateTime.now();
    final notification = {
      'title': title,
      'body': body,
      'timestamp': now.toIso8601String(),
    };

    final existingNotifications = await getNotifications(studentId);
    existingNotifications.add(notification);
    final encodedNotifications = jsonEncode(existingNotifications);
    await prefs.setString(notificationKey, encodedNotifications);
  }

  // Get notifications using the consistent key format
  Future<List<Map<String, dynamic>>> getNotifications(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationKey = 'notifications_$studentId'; // Consistent key
    final encodedNotifications = prefs.getString(notificationKey);

    if (encodedNotifications == null) {
      return [];
    }
    try {
      final decodedNotifications = jsonDecode(encodedNotifications) as List<dynamic>;
      return decodedNotifications
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      print("Error decoding notifications: $e");
      return [];
    }
  }

  Future<void> removeNotificationFlag(String studentId) async {
    final prefs = await SharedPreferences.getInstance();

    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('notification_sent_$studentId') ||
          key.startsWith('notifications_$studentId')) {
        await prefs.remove(key);
      }
    }
  }
}

final notificationService = NotificationService();
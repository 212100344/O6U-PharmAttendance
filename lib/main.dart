// lib/main.dart
import 'package:attendance_sys/utils/supabase.dart';
import 'package:flutter/material.dart';
import 'SplashScreen.dart';
import 'package:attendance_sys/utils/notification_service.dart';
import 'package:attendance_sys/Student/StudentHome.dart';
import 'package:attendance_sys/Admin/AdminHome.dart';
import 'package:attendance_sys/Trainee%20Supervisor/TraineeSupervisorHome.dart';
import 'AdminStudent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const checkStatusTaskKey = "checkStatusTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async { // inputData is now used
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Your app's icon
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    try {
      await SupabaseConfig.initialize();

      // Get the email from inputData, NOT SharedPreferences
      final studentEmail = inputData?['email'] as String?; // Use inputData

      if (studentEmail != null) {
        final response = await SupabaseConfig.client
            .from('profiles')
            .select('status, role') // Select the role as well!
            .eq('email', studentEmail)
            .maybeSingle();

        final currentStatus = response?['status'] as String?;
        final userRole = response?['role'] as String?; // Get the role

        // Only send the notification if the account is ACTIVE and the role is STUDENT
        if (currentStatus == 'active' && userRole == 'student') {
          final hasSent =
          await notificationService.hasNotificationBeenSent(studentEmail);
          if (!hasSent) {
            await notificationService.showNotification(
              studentEmail.hashCode, // Unique ID
              "Account Approved",
              "Your O6U Pharmacy account has been approved!",
            );
            await notificationService.setNotificationSentFlag(studentEmail);
            Workmanager().cancelByUniqueName(checkStatusTaskKey);
            print("Background task CANCELED.");
          }
        }
      } else {
        print("callbackDispatcher: No email provided in inputData.");
      }

    } catch (e) {
      print("Error in background task: $e");
      return Future.value(false); // Indicate failure
    }

    return Future.value(true); // Indicate success
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await notificationService.init();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      //in main.dart
      routes: {
        '/': (context) => const SplashScreen(title: 'Attendance System'),
        '/studenthome': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final email = args['email'] as String;
          return StudentHome(email: email);
        },
        '/adminhome': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final email = args['email'] as String;
          return AdminHome(email: email);
        },
        '/supervisorhome': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final email = args['email'] as String;
          return TraineeSupervisorHome(email: email);
        },
        '/adminStudent': (context) => const AdminStudent(),
      },
      initialRoute: '/',
    );
  }
}
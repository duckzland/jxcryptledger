import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Linux Setup
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Notification',
      //defaultIcon: 'assets/icon.png', // Ensure this exists
    );

    // 2. Windows Setup
    // Uses the companion package: flutter_local_notifications_windows
    // No specific InitializationSettings object needed here,
    // but the plugin handles the platform check internally.

    const initSettings = InitializationSettings(
      linux: linuxSettings,
      // Add android/iOS here if needed later
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle click events here safely on the main thread
      },
    );
  }

  Future<void> show(String message) async {
    // Platform-specific details
    const linuxDetails = LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal);

    const windowsDetails = WindowsNotificationDetails(); // Standard toast

    const notificationDetails = NotificationDetails(linux: linuxDetails, windows: windowsDetails);

    await _plugin.show(
      id: 0, // ID
      title: 'JXLedger', // Title
      body: message, // Body
      notificationDetails: notificationDetails,
    );
  }
}

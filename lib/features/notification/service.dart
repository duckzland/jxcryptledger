import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    final String exePath = File(Platform.resolvedExecutable).parent.path;
    final String iconPath = p.join(exePath, 'data', 'flutter_assets', 'assets', 'icon.png');

    final windowsSettings = WindowsInitializationSettings(
      appName: 'JXLedger',
      appUserModelId: 'com.duckzland.jxledger',
      guid: '3900e1e5-8211-4bab-82d7-0dea9e1db2cd',
      iconPath: iconPath,
    );

    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Notification',
      defaultIcon: AssetsLinuxIcon('assets/icon.png'),
    );

    final initSettings = InitializationSettings(linux: linuxSettings, windows: windowsSettings);

    await _plugin.initialize(settings: initSettings, onDidReceiveNotificationResponse: (details) {});
  }

  Future<void> show(String message) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      linux: LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal),
      windows: WindowsNotificationDetails(),
    );

    await _plugin.show(id: 0, title: null, body: message, notificationDetails: notificationDetails);
  }
}

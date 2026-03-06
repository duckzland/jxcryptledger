import 'dart:io';
import 'package:win_toast/win_toast.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

import '../../core/log.dart';

class NotificationService {
  NotificationsClient? linuxClient;

  Future<void> init() async {
    if (Platform.isWindows) {
      final icon = "${Directory.current.path}\\assets\\icon.png";
      await WinToast.instance().initialize(
        aumId: "com.duckzland.jxcryptledger",
        displayName: "JxCryptLedger",
        iconPath: icon,
        clsid: "3900e1e5-8211-4bab-82d7-0dea9e1db2cd",
      );

      WinToast.instance().setActivatedCallback(null);
      WinToast.instance().setDismissedCallback(null);
    }

    if (Platform.isLinux) {
      linuxClient = NotificationsClient();
    }
  }

  Future<void> show(String message) async {
    logln("[Notification] Firing notification for: $message");
    if (Platform.isWindows) {
      final xml =
          '''
<toast scenario="reminder">
  <visual>
    <binding template="ToastGeneric">
      <text>$message</text>
    </binding>
  </visual>
</toast>

''';

      await WinToast.instance().showCustomToast(xml: xml);

      return;
    }

    if (Platform.isLinux) {
      await linuxClient?.notify(message);
      return;
    }
  }
}

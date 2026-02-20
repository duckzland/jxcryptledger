import 'package:flutter/material.dart';
import '../../app/layout.dart';
import '../../core/locator.dart'; // Import your locator
import 'form.dart';
import 'controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Grab the global instance of the controller
    final controller = locator<SettingsController>();

    return AppLayout(
      title: "Settings",
      showBack: true,
      // Inject the actual grid screen
      child: SettingsForm(controller: controller),
    );
  }
}

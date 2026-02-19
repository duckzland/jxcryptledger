import 'package:flutter/material.dart';
import '../../app/layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Settings",
      showBack: true,
      child: const Center(child: Text("Settings Form Placeholder")),
    );
  }
}

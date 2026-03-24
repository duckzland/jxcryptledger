import 'package:flutter/material.dart';

class AppPage extends StatelessWidget {
  final Widget child;
  const AppPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Fix for ghost beep on windows when clicked at empty space.
      },
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const WidgetsTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

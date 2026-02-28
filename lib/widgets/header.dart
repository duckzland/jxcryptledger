import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  final Color titleColor;
  final Color subtitleColor;

  const WidgetsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleColor = AppTheme.text,
    this.subtitleColor = AppTheme.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: subtitleColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

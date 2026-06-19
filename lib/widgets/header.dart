import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  final Color titleColor;
  final Color subtitleColor;

  final bool reversed;

  const WidgetsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleColor = AppTheme.text,
    this.subtitleColor = AppTheme.textMuted,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      if (title != "")
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor),
        ),
      if (title != "") const SizedBox(height: 1),
      if (subtitle != "")
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: subtitleColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reversed ? items.reversed.toList() : items,
    );
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsWithTooltip extends StatelessWidget {
  final Widget content;
  final String? message;

  final bool showIcon;
  const WidgetsWithTooltip(this.content, this.message, {super.key, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return content;
    }

    return Tooltip(
      message: message!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          content,
          if (showIcon)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

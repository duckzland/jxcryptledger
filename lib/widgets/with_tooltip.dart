import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsWithTooltip extends StatelessWidget {
  final Widget content;
  final String? message;
  final String? accent;

  final bool showIcon;
  const WidgetsWithTooltip(this.content, this.message, this.accent, {super.key, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    if (message == null && !showIcon) {
      return content;
    }

    final Color? ac = int.tryParse(accent ?? '', radix: 16) != null ? Color(int.parse(accent!, radix: 16)) : null;

    return Tooltip(
      message: message ?? "",
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          content,
          if (showIcon)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: ac ?? Colors.transparent, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

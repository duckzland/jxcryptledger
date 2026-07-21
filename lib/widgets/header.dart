import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;

  final Color titleColor;
  final Color subtitleColor;

  final bool reversed;
  final bool centered;

  final double titleFontSize;
  final double subtitleFontSize;
  final double spacing;

  final FontWeight titleFontWeight;
  final FontWeight subtitleFontWeight;

  final List<Widget>? children;
  final Widget? child;

  const WidgetsHeader({
    super.key,
    this.title,
    this.subtitle,
    this.titleColor = AppTheme.text,
    this.titleFontSize = 14,
    this.titleFontWeight = FontWeight.w600,

    this.subtitleColor = AppTheme.textMuted,
    this.subtitleFontSize = 11,
    this.subtitleFontWeight = FontWeight.w400,

    this.reversed = false,
    this.centered = false,
    this.spacing = 1,
    this.children,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      if (title != null && title != "")
        Text(
          title!,
          style: TextStyle(fontSize: titleFontSize, fontWeight: titleFontWeight, color: titleColor),
        ),
      if (subtitle != null && subtitle != "")
        Text(
          subtitle!,
          style: TextStyle(fontSize: subtitleFontSize, fontWeight: subtitleFontWeight, color: subtitleColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
    ];

    if (reversed) {
      items = items.reversed.toList();
    }

    if (child != null) {
      items.add(child!);
    }

    if (children != null) {
      items = [...items, ...children!];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      spacing: spacing,
      children: items,
    );
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;
  final double borderRadius;

  const WidgetsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderColor,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppTheme.panelBg,
        border: Border.all(color: borderColor ?? AppTheme.separator),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

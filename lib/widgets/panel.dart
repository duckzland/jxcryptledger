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
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: ShapeDecoration(
        color: background ?? AppTheme.panelBg,
        shape: ContinuousRectangleBorder(
          side: BorderSide(color: borderColor ?? AppTheme.separator, width: 1.0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: child,
    );
  }
}

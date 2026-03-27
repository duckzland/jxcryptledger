import 'package:flutter/material.dart';

import '../app/theme.dart';

class WidgetsSeparator extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final EdgeInsets padding;

  const WidgetsSeparator({
    super.key,
    this.width = 1,
    this.height = 24,
    this.color = AppTheme.separator,
    this.padding = const EdgeInsets.all(0.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: AppTheme.separator);
  }
}

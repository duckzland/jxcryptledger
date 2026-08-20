import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../numbers/flow.dart';
import 'selectable.dart';

class WidgetsTextBalance extends StatelessWidget {
  final String text;
  final double value;
  final double comparator;
  final double? fontSize;
  final bool? hidePrefix;
  final bool? animated;
  final bool? selectable;
  final FontWeight? fontWeight;

  const WidgetsTextBalance({
    super.key,
    required this.text,
    this.value = 0.0,
    this.comparator = 0.0,
    this.fontSize,
    this.hidePrefix,
    this.animated = false,
    this.selectable = true,
    this.fontWeight,
  });

  int _mode() {
    if (value == comparator) return 0;
    if (value > comparator) return 1;
    return -1;
  }

  Color _colorForMode(int mode) {
    switch (mode) {
      case 1:
        return AppTheme.profit;
      case -1:
        return AppTheme.loss;
      default:
        return AppTheme.text;
    }
  }

  String _prefixForMode(int mode) {
    if (hidePrefix == true) {
      return "";
    }
    switch (mode) {
      case 1:
        return "+";
      case -1:
        return value > 0 ? "-" : "";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode();
    final color = _colorForMode(mode);
    final prefix = _prefixForMode(mode);

    if (animated == null || !animated!) {
      return selectable == true
          ? WidgetsTextSelectable(
              "$prefix$text",
              style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
            )
          : Text(
              "$prefix$text",
              style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
            );
    }

    return WidgetsNumbersFlow(
      begin: "",
      end: text,
      prefix: prefix,
      selectable: selectable!,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
    );
  }
}

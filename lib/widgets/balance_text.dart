import 'package:flutter/widgets.dart';

import '../app/theme.dart';

class WidgetsBalanceText extends StatelessWidget {
  final String text;
  final double value;
  final double comparator;
  final double? fontSize;
  final bool? hidePrefix;

  const WidgetsBalanceText({
    super.key,
    required this.text,
    required this.value,
    required this.comparator,
    this.fontSize,
    this.hidePrefix,
  });

  int _mode() {
    if (value == comparator) return 0;
    if (value > comparator) return 1;
    return -1;
  }

  Color _colorForMode(int mode) {
    switch (mode) {
      case 1:
        return AppTheme.success;
      case -1:
        return AppTheme.error;
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
        return "-";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode();
    final color = _colorForMode(mode);
    final prefix = _prefixForMode(mode);

    return Text(
      "$prefix$text",
      style: TextStyle(color: color, fontSize: fontSize),
    );
  }
}

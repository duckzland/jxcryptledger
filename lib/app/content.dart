import 'package:flutter/material.dart';

import 'theme.dart';

class AppContent extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final BoxConstraints boxConstraints;
  final List<Widget> children;
  final bool centering;
  final bool fullwidth;
  final double spacing;

  const AppContent({
    super.key,
    this.padding,
    this.boxConstraints = const BoxConstraints(maxWidth: AppTheme.pageMaxWidth),
    this.centering = true,
    this.fullwidth = false,
    this.spacing = 12,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (children.length > 1) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: spacing,
        children: children,
      );
    } else {
      content = children.first;
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (!fullwidth) {
      content = ConstrainedBox(constraints: boxConstraints, child: content);
    }

    if (centering) {
      content = Center(child: content);
    }

    return content;
  }
}

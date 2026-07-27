import 'package:flutter/material.dart';

class AppContent extends StatelessWidget {
  final BoxConstraints? boxConstraints;
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;
  final bool centering;
  final double spacing;
  const AppContent({super.key, this.boxConstraints, this.padding, this.centering = true, this.spacing = 12, required this.children});

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: spacing,
      children: children,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (boxConstraints != null) {
      content = ConstrainedBox(constraints: boxConstraints!, child: content);
    }

    if (centering) {
      content = Center(child: content);
    }

    return content;
  }
}

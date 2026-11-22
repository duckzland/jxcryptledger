import 'package:flutter/material.dart';

import 'box.dart';

class WidgetsTableProxy extends SingleChildRenderObjectWidget {
  final ScrollController controller;
  final double headerHeight;
  final double rowHeight;
  final double topOffset;
  final double minHeight;
  final Color background;

  const WidgetsTableProxy({
    super.key,
    required this.controller,
    required super.child,
    this.headerHeight = 50.0,
    this.rowHeight = 42.0,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
  });

  @override
  WidgetsTableBox createRenderObject(BuildContext context) {
    return WidgetsTableBox(
      controller: controller,
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      topOffset: topOffset,
      minHeight: minHeight,
      background: background,
    );
  }

  @override
  void updateRenderObject(BuildContext context, WidgetsTableBox renderObject) {
    renderObject
      ..controller = controller
      ..headerHeight = headerHeight
      ..rowHeight = rowHeight
      ..topOffset = topOffset
      ..minHeight = minHeight
      ..background = background;
  }
}

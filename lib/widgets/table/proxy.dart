import 'package:data_table_2/data_table_2.dart';
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
    required DataTable2 child,

    this.headerHeight = 50.0,
    this.rowHeight = 42.0,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
  }) : super(child: child);

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

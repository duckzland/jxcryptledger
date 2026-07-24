import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import 'box.dart';

class WidgetsTableHeaderProxy extends SingleChildRenderObjectWidget {
  final ScrollController controller;
  final double headerHeight;
  final double rowHeight;
  final double topOffset;
  final double minHeight;
  final Color background;

  const WidgetsTableHeaderProxy({
    super.key,
    required this.controller,
    this.headerHeight = 50.0,
    this.rowHeight = 42.0,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
    required DataTable2 child,
  }) : super(child: child);

  @override
  WidgetsTableHeaderBox createRenderObject(BuildContext context) {
    return WidgetsTableHeaderBox(
      controller: controller,
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      topOffset: topOffset,
      minHeight: minHeight,
      background: background,
    );
  }

  @override
  void updateRenderObject(BuildContext context, WidgetsTableHeaderBox renderObject) {
    renderObject
      ..controller = controller
      ..headerHeight = headerHeight
      ..rowHeight = rowHeight
      ..topOffset = topOffset
      ..minHeight = minHeight
      ..background = background;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../column.dart';
import 'painter.dart';

class WidgetsTableHeaderLayoutProxy extends SingleChildRenderObjectWidget {
  final ScrollController controller;
  final double headerHeight;
  final double rowHeight;
  final double topOffset;
  final double minHeight;
  final Color background;

  WidgetsTableHeaderLayoutProxy({
    super.key,
    required this.controller,
    this.headerHeight = 50.0,
    this.rowHeight = 42.0,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
    required Widget child,
  }) : super(
         child: WidgetsTableHeaderPainterProxy(
           pageController: controller,
           headerHeight: headerHeight,
           rowHeight: rowHeight,
           topOffset: topOffset,
           minHeight: minHeight,
           background: background,
           child: child,
         ),
       );

  @override
  WidgetsTableHeaderLayoutBox createRenderObject(BuildContext context) {
    return WidgetsTableHeaderLayoutBox(
      controller: controller,
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      topOffset: topOffset,
      minHeight: minHeight,
    );
  }

  @override
  void updateRenderObject(BuildContext context, WidgetsTableHeaderLayoutBox renderObject) {
    renderObject
      ..controller = controller
      ..headerHeight = headerHeight
      ..rowHeight = rowHeight
      ..topOffset = topOffset
      ..minHeight = minHeight;
  }
}

class WidgetsTableHeaderLayoutBox extends RenderProxyBox {
  ScrollController controller;
  double headerHeight;
  double rowHeight;
  double topOffset;
  double minHeight;

  WidgetsTableHeaderLayoutBox({
    required this.controller,
    required this.headerHeight,
    required this.rowHeight,
    required this.topOffset,
    required this.minHeight,
  }) {
    controller.addListener(_onScrollUpdate);
  }

  void _onScrollUpdate() => markNeedsLayout();

  @override
  void detach() {
    controller.removeListener(_onScrollUpdate);
    super.detach();
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = child!.size;
    } else {
      size = constraints.smallest;
      return;
    }

    RenderTable? table;
    RenderBox? header;

    void walkTree(RenderObject object) {
      if (table != null) return;
      if (object is WidgetsTableColumnRenderElement) {
        header = object as RenderBox;
        RenderObject? current = object.parent;
        while (current != null && current != child) {
          if (current is RenderTable) {
            table = current;
            break;
          }
          current = current.parent;
        }
        return;
      }
      object.visitChildren(walkTree);
    }

    child!.visitChildren(walkTree);

    if (header == null || !header!.attached) return;
    if (table == null || !table!.attached) return;
    if (size.height < minHeight) return;

    double offsetY = 0.0;

    try {
      final double tableHeight = size.height;
      final double currentScroll = controller.offset;
      final double startY = (header?.localToGlobal(Offset.zero).dy ?? 0.0) + currentScroll;
      final double distancePastTop = currentScroll - startY + topOffset;
      final double maxDistance = math.max(0.0, tableHeight - headerHeight - (rowHeight * 2));

      offsetY = distancePastTop.clamp(0.0, maxDistance);
    } catch (e) {
      return;
    }

    RenderObject? target = child;
    while (target is RenderProxyBox) {
      if (target is WidgetsTableHeaderPainterBox) {
        final newOffset = offsetY;
        if (target.offsetY != newOffset) {
          target.offsetY = newOffset;
          target.markNeedsPaint();
        }
        break;
      }
      target = target.child;
    }
  }
}

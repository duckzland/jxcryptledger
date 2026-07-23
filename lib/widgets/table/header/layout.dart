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
  ScrollController _controller;
  double headerHeight;
  double rowHeight;
  double topOffset;
  double minHeight;

  WidgetsTableHeaderLayoutBox({
    required ScrollController controller,
    required this.headerHeight,
    required this.rowHeight,
    required this.topOffset,
    required this.minHeight,
  }) : _controller = controller {
    _controller.addListener(_onScrollUpdate);
  }

  set controller(ScrollController value) {
    if (_controller == value) return;
    _controller.removeListener(_onScrollUpdate);
    _controller = value;
    _controller.addListener(_onScrollUpdate);
    markNeedsLayout();
  }

  void _onScrollUpdate() => markNeedsLayout();

  double? _absoluteTableStartY;

  @override
  void detach() {
    _controller.removeListener(_onScrollUpdate);
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

    double calculatedOffsetY = 0.0;

    if (table != null && table!.attached && header != null && header!.attached) {
      final double tableHeight = size.height;
      if (tableHeight > minHeight) {
        final double currentScroll = _controller.offset;

        if (_absoluteTableStartY == null) {
          try {
            _absoluteTableStartY = header!.localToGlobal(Offset.zero).dy + currentScroll;
          } catch (_) {
            _absoluteTableStartY = null;
          }
        }

        if (_absoluteTableStartY != null) {
          final double distancePastTop = currentScroll - _absoluteTableStartY! + topOffset;
          final double maxDistance = math.max(0.0, tableHeight - headerHeight - (rowHeight * 2));

          double scrollTo = distancePastTop;
          if (scrollTo >= maxDistance) {
            scrollTo = maxDistance;
          }
          calculatedOffsetY = (scrollTo <= 0.0) ? 0.0 : scrollTo;
        }
      }
    } else {
      _absoluteTableStartY = null;
    }

    RenderObject? target = child;
    while (target != null) {
      if (target is WidgetsTableHeaderPainterBox) {
        if (target.offsetY != calculatedOffsetY) {
          target.offsetY = calculatedOffsetY;
          target.markNeedsPaint();
        }
        break;
      }
      if (target is RenderProxyBox) {
        target = target.child;
      } else {
        break;
      }
    }
  }
}

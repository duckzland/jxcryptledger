import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../column.dart';

class WidgetsTableHeaderPainterProxy extends SingleChildRenderObjectWidget {
  final ScrollController pageController;
  final double headerHeight;
  final double rowHeight;
  final double topOffset;
  final double minHeight;
  final Color background;

  const WidgetsTableHeaderPainterProxy({
    super.key,
    required this.pageController,
    this.headerHeight = 50,
    this.rowHeight = 42,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
    required Widget super.child,
  });

  @override
  WidgetsTableHeaderPainterBox createRenderObject(BuildContext context) {
    return WidgetsTableHeaderPainterBox(
      controller: pageController,
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      topOffset: topOffset,
      minHeight: minHeight,
      background: background,
    );
  }

  @override
  void updateRenderObject(BuildContext context, WidgetsTableHeaderPainterBox renderObject) {
    renderObject
      ..controller = pageController
      ..headerHeight = headerHeight
      ..rowHeight = rowHeight
      ..topOffset = topOffset
      ..minHeight = minHeight
      ..background = background;
  }
}

class WidgetsTableHeaderPainterBox extends RenderProxyBox {
  ScrollController _controller;
  double headerHeight;
  double rowHeight;
  double topOffset;
  double minHeight;
  Color background;

  double offsetY = 0.0;

  WidgetsTableHeaderPainterBox({
    required ScrollController controller,
    this.headerHeight = 50,
    this.rowHeight = 42,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
  }) : _controller = controller;

  set controller(ScrollController value) {
    if (_controller == value) return;
    _controller = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    RenderTable? table;

    void walkTree(RenderObject object) {
      if (table != null) return;
      if (object is WidgetsTableColumnRenderElement) {
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

    if (table != null && table!.attached && offsetY > 0.0) {
      final Rect bodyClipBox = Rect.fromLTWH(offset.dx, offset.dy + headerHeight, size.width, size.height - headerHeight);

      context.pushClipRect(needsCompositing, offset, bodyClipBox, (PaintingContext bodyCtx, Offset bodyOff) {
        bodyCtx.paintChild(child!, bodyOff);
      });

      final Offset headerTranslateOffset = offset.translate(0, offsetY);

      context.pushTransform(
        needsCompositing,
        Offset.zero,
        Matrix4.translationValues(headerTranslateOffset.dx, headerTranslateOffset.dy, 0.0),
        (PaintingContext headerCtx, Offset headerOff) {
          headerCtx.canvas.save();

          final Paint bgPaint = Paint()..color = background;
          headerCtx.canvas.drawRect(Rect.fromLTWH(0.0, 0.0, size.width, headerHeight), bgPaint);

          table!.visitChildren((RenderObject cellBox) {
            if (cellBox is RenderBox && cellBox.parentData is TableCellParentData) {
              final TableCellParentData cellData = cellBox.parentData as TableCellParentData;

              if (cellData.y == 0) {
                final double cellX = cellData.offset.dx;
                headerCtx.paintChild(cellBox, Offset(cellX, 0.0));
              }
            }
          });

          headerCtx.canvas.restore();
        },
      );
    } else {
      context.paintChild(child!, offset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
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

    if (child != null) walkTree(child!);

    if (table != null && table!.attached && header != null && header!.attached && offsetY > 0.0) {
      final Offset tableOffset = table!.localToGlobal(Offset.zero, ancestor: this);

      final double tableTopEdge = tableOffset.dy;
      final double tableBottomEdge = tableOffset.dy + child!.size.height;

      final Rect stickyHeaderRect = Rect.fromLTWH(tableOffset.dx, tableTopEdge + offsetY, child!.size.width, headerHeight);

      if (position.dy >= tableTopEdge && position.dy <= tableBottomEdge && stickyHeaderRect.contains(position)) {
        final Offset translatedPosition = position.translate(0.0, -offsetY);

        final bool hitChild = child!.hitTest(result, position: translatedPosition);

        if (!hitChild) {
          result.add(BoxHitTestEntry(this, position));
        } else {
          Future.microtask(() {
            if (attached) {
              markNeedsPaint();
              child?.markNeedsPaint();
            }
          });
        }

        return true;
      }
    }

    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;

    if (offsetY > 0.0) {
      final double headerTop = offsetY;
      final double headerBottom = offsetY + headerHeight;

      if (position.dy >= headerTop && position.dy <= headerBottom) {
        final Offset translatedPosition = position.translate(0.0, -offsetY);
        final bool hitChild = child!.hitTest(result, position: translatedPosition);

        if (!hitChild) {
          result.add(BoxHitTestEntry(this, position));
        }

        return true;
      }
    }

    return super.hitTestChildren(result, position: position);
  }
}

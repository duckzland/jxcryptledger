import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../column.dart';

class WidgetsTableHeaderBox extends RenderProxyBox {
  ScrollController controller;
  double headerHeight;
  double rowHeight;
  double topOffset;
  double minHeight;
  Color background;

  WidgetsTableHeaderBox({
    required this.controller,
    required this.headerHeight,
    required this.rowHeight,
    required this.topOffset,
    required this.minHeight,
    this.background = Colors.black,
  }) {
    controller.addListener(_onScrollUpdate);
  }

  double _offsetY = 0.0;
  RenderTable? _table;
  RenderBox? _header;

  @override
  void detach() {
    controller.removeListener(_onScrollUpdate);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    child!.visitChildren(_walkTree);

    if (_table == null || !_table!.attached || _offsetY <= 0.0) {
      context.paintChild(child!, offset);
      return;
    }

    final Rect bodyClipBox = Rect.fromLTWH(offset.dx, offset.dy + headerHeight, size.width, size.height - headerHeight);

    context.pushClipRect(needsCompositing, offset, bodyClipBox, (PaintingContext bodyCtx, Offset bodyOff) {
      bodyCtx.paintChild(child!, bodyOff);
    });

    final Offset headerTranslateOffset = offset.translate(0, _offsetY);

    context.pushTransform(
      needsCompositing,
      Offset.zero,
      Matrix4.translationValues(headerTranslateOffset.dx, headerTranslateOffset.dy, 0.0),
      (PaintingContext headerCtx, Offset headerOff) {
        headerCtx.canvas.save();

        final Paint bgPaint = Paint()..color = background;
        headerCtx.canvas.drawRect(Rect.fromLTWH(0.0, 0.0, size.width, headerHeight), bgPaint);

        _table!.visitChildren((RenderObject cellBox) {
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
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (child != null) _walkTree(child!);

    if (_table != null && _table!.attached && _header != null && _header!.attached && _offsetY > 0.0) {
      final Offset tableOffset = _table!.localToGlobal(Offset.zero, ancestor: this);

      final double tableTopEdge = tableOffset.dy;
      final double tableBottomEdge = tableOffset.dy + child!.size.height;

      final Rect stickyHeaderRect = Rect.fromLTWH(tableOffset.dx, tableTopEdge + _offsetY, child!.size.width, headerHeight);

      if (position.dy >= tableTopEdge && position.dy <= tableBottomEdge && stickyHeaderRect.contains(position)) {
        final Offset translatedPosition = position.translate(0.0, -_offsetY);

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

    if (_offsetY > 0.0) {
      final double headerTop = _offsetY;
      final double headerBottom = _offsetY + headerHeight;

      if (position.dy >= headerTop && position.dy <= headerBottom) {
        final Offset translatedPosition = position.translate(0.0, -_offsetY);
        final bool hitChild = child!.hitTest(result, position: translatedPosition);

        if (!hitChild) {
          result.add(BoxHitTestEntry(this, position));
        }

        return true;
      }
    }

    return super.hitTestChildren(result, position: position);
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

    child!.visitChildren(_walkTree);

    if (_header == null || !_header!.attached) return;
    if (_table == null || !_table!.attached) return;
    if (size.height < minHeight) return;

    try {
      final double tableHeight = size.height;
      final double currentScroll = controller.offset;
      final double startY = (_header?.localToGlobal(Offset.zero).dy ?? 0.0) + currentScroll;
      final double distancePastTop = currentScroll - startY + topOffset;
      final double maxDistance = math.max(0.0, tableHeight - headerHeight - (rowHeight * 2));
      final double newOffsetY = distancePastTop.clamp(0.0, maxDistance);

      if (newOffsetY != _offsetY) {
        _offsetY = newOffsetY;
        child!.markNeedsPaint();
      }
    } catch (e) {
      return;
    }
  }

  void _onScrollUpdate() {
    markNeedsLayout();
  }

  void _walkTree(RenderObject object) {
    if (_table != null && _header != null) return;

    if (object is WidgetsTableColumnRenderElement) {
      _header = object as RenderBox;
      RenderObject? current = object.parent;
      while (current != null && current != child) {
        if (current is RenderTable) {
          _table = current;
          break;
        }
        current = current.parent;
      }
      return;
    }
    object.visitChildren(_walkTree);
  }
}

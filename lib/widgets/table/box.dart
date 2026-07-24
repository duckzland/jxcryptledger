import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'column.dart';

class WidgetsTableBox extends RenderProxyBox {
  ScrollController controller;
  double headerHeight;
  double rowHeight;
  double topOffset;
  double minHeight;
  Color background;

  WidgetsTableBox({
    required this.controller,
    required this.headerHeight,
    required this.rowHeight,
    required this.topOffset,
    required this.minHeight,
    required this.background,
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

    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(offset.dx, offset.dy + headerHeight, size.width, size.height - headerHeight),
      (PaintingContext ctx, Offset bOffset) {
        ctx.paintChild(child!, bOffset);
      },
    );

    final Offset tOffset = offset.translate(0, _offsetY);

    context.pushTransform(needsCompositing, Offset.zero, Matrix4.translationValues(tOffset.dx, tOffset.dy, 0.0), (
      PaintingContext ctx,
      Offset hOffset,
    ) {
      ctx.canvas.save();

      final Paint bg = Paint()..color = background;
      ctx.canvas.drawRect(Rect.fromLTWH(0.0, 0.0, size.width, headerHeight), bg);

      _table!.visitChildren((RenderObject box) {
        if (box is RenderBox && box.parentData is TableCellParentData) {
          final TableCellParentData data = box.parentData as TableCellParentData;

          if (data.y == 0) {
            ctx.paintChild(box, Offset(data.offset.dx, 0.0));
          }
        }
      });

      ctx.canvas.restore();
    });
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (child != null) _walkTree(child!);

    if (_table != null && _table!.attached && _header != null && _header!.attached && _offsetY > 0.0) {
      final Offset tOffset = _table!.localToGlobal(Offset.zero, ancestor: this);

      final double topEdge = tOffset.dy;
      final double bottomEdge = tOffset.dy + child!.size.height;

      final Rect rect = Rect.fromLTWH(tOffset.dx, topEdge + _offsetY, child!.size.width, headerHeight);

      if (position.dy >= topEdge && position.dy <= bottomEdge && rect.contains(position)) {
        final bool hitChild = child!.hitTest(result, position: position.translate(0.0, -_offsetY));

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
      if (position.dy >= _offsetY && position.dy <= (_offsetY + headerHeight)) {
        if (!child!.hitTest(result, position: position.translate(0.0, -_offsetY))) {
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

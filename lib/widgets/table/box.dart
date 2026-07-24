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
  Paint? bgPaint;

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

    _walkTree(child!);

    if (_table == null || !_table!.attached || _offsetY <= 0.0) {
      context.paintChild(child!, offset);
      return;
    }

    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(offset.dx, offset.dy + headerHeight, size.width, size.height - headerHeight),
      _paintBackground,
    );

    final Offset tOffset = offset.translate(0, _offsetY);
    context.pushTransform(needsCompositing, Offset.zero, Matrix4.translationValues(tOffset.dx, tOffset.dy, 0.0), _paintTransformedHeader);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;

    _walkTree(child!);

    if (_table != null && _table!.attached && _header != null && _header!.attached && _offsetY > 0.0) {
      final Offset offset = _table!.localToGlobal(Offset.zero, ancestor: this);

      final double topEdge = offset.dy;
      final double bottomEdge = offset.dy + child!.size.height;

      final Rect rect = Rect.fromLTWH(offset.dx, topEdge + _offsetY, child!.size.width, headerHeight);

      if (position.dy >= topEdge && position.dy <= bottomEdge && rect.contains(position)) {
        if (!child!.hitTest(result, position: position.translate(0.0, -_offsetY))) {
          result.add(BoxHitTestEntry(this, position));
        } else {
          // BugFix: the checkbox at header stutter when clicked and the sort arrow flashes when hovered.
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

    _walkTree(child!);

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
        _header!.markNeedsPaint();
      }
    } catch (e) {
      return;
    }
  }

  void _onScrollUpdate() {
    if (size.height > minHeight) {
      markNeedsLayout();
    }
  }

  void _walkTree(RenderObject object) {
    if (_table != null && _header != null) return;

    if (object is WidgetsTableColumnRenderElement) {
      _header = object as RenderBox;
      RenderObject? current = object.parent;
      while (current != null && current != child) {
        if (current is RenderTable) {
          // Need a RenderTable not DataTable2 itself.
          _table = current;
          break;
        }
        current = current.parent;
      }
      return;
    }
    object.visitChildren(_walkTree);
  }

  void _paintBackground(PaintingContext ctx, Offset offset) {
    ctx.paintChild(child!, offset);
  }

  void _paintTransformedHeader(PaintingContext ctx, Offset offset) {
    ctx.canvas.save();

    bgPaint ??= Paint()..color = background;
    ctx.canvas.drawRect(Rect.fromLTWH(0.0, 0.0, size.width, headerHeight), bgPaint!);

    _table!.visitChildren((RenderObject box) {
      if (box is RenderBox && box.parentData is TableCellParentData) {
        final TableCellParentData data = box.parentData as TableCellParentData;

        if (data.y == 0) {
          ctx.paintChild(box, Offset(data.offset.dx, 0.0));
        }
      }
    });

    ctx.canvas.restore();
  }
}

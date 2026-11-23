import 'package:flutter/material.dart';
import 'base.dart';

class WidgetsTableVirtualizedMultiple<T> extends WidgetsTableVirtualizedBase<T> {
  final double positionTop;
  final bool lateRefresh;

  const WidgetsTableVirtualizedMultiple({
    super.key,
    required super.controller,
    required super.data,
    required super.rowBuilder,
    required super.columnCount,
    required super.childBuilder,
    required this.positionTop,
    super.headerHeight,
    super.rowHeight,
    super.topOffset,
    super.minHeight,
    super.background,
    super.loaderBuilder,
    super.viewportMultiplier,
    this.lateRefresh = false,
  });

  @override
  State<WidgetsTableVirtualizedMultiple<T>> createState() => _WidgetsTableVirtualizedMultipleState<T>();
}

class _WidgetsTableVirtualizedMultipleState<T> extends WidgetsTableVirtualizedBaseState<T, WidgetsTableVirtualizedMultiple<T>> {
  @override
  bool get shouldLateRefresh => widget.lateRefresh;

  @override
  (int, int) computeRawRange(ScrollPosition pos) {
    final top = pos.pixels - widget.positionTop - (widget.headerHeight + 12);
    final rawStart = (top / widget.rowHeight).floor();
    final rawEnd = ((top + pos.viewportDimension) / widget.rowHeight).ceil();
    return (rawStart, rawEnd);
  }
}

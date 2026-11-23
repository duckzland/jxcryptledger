import 'package:flutter/material.dart';
import 'base.dart';

class WidgetsTableVirtualizedSingle<T> extends WidgetsTableVirtualizedBase<T> {
  const WidgetsTableVirtualizedSingle({
    super.key,
    required super.controller,
    required super.data,
    required super.rowBuilder,
    required super.columnCount,
    required super.childBuilder,
    super.headerHeight,
    super.rowHeight,
    super.topOffset = 0.0,
    super.minHeight,
    super.background,
    super.loaderBuilder,
    super.viewportMultiplier,
  });

  @override
  State<WidgetsTableVirtualizedSingle<T>> createState() => _WidgetsTableVirtualizedSingleState<T>();
}

class _WidgetsTableVirtualizedSingleState<T> extends WidgetsTableVirtualizedBaseState<T, WidgetsTableVirtualizedSingle<T>> {
  @override
  (int, int) computeRawRange(ScrollPosition pos) {
    final top = pos.pixels;
    final rawStart = (top / widget.rowHeight).floor();
    final rawEnd = ((top + pos.viewportDimension - (widget.headerHeight + 12)) / widget.rowHeight).ceil();
    return (rawStart, rawEnd);
  }
}

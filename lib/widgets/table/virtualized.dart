import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import 'proxy.dart';

class WidgetsTableVirtualized<T> extends StatefulWidget {
  final ScrollController controller;
  final List<T> data;
  final DataRow Function(T row) rowBuilder;
  final int columnCount;
  final Widget Function(List<DataRow> rows) childBuilder;

  final double headerHeight;
  final double rowHeight;
  final double topOffset;
  final double minHeight;
  final Color background;
  final bool isGroup;
  final double? positionTop;
  final GlobalKey? tableKey;
  final Widget Function()? loaderBuilder;
  final double viewportMultiplier;

  const WidgetsTableVirtualized({
    super.key,
    required this.controller,
    required this.data,
    required this.rowBuilder,
    required this.columnCount,
    required this.childBuilder,
    this.headerHeight = 50.0,
    this.rowHeight = 42.0,
    this.topOffset = 70.0,
    this.minHeight = 126.0,
    this.background = Colors.black,
    this.isGroup = false,
    this.positionTop,
    this.tableKey,
    this.loaderBuilder,
    this.viewportMultiplier = 2.5,
  });

  @override
  State<WidgetsTableVirtualized<T>> createState() =>
      _WidgetsTableVirtualizedState<T>();
}

class _WidgetsTableVirtualizedState<T>
    extends State<WidgetsTableVirtualized<T>> {
  int _rowStart = 0;
  int _rowEnd = 0;
  int _rowCount = -1;
  double _scrollPosition = 0.0;

  int get _viewportRows {
    final height = widget.controller.hasClients
        ? widget.controller.position.viewportDimension
        : widget.rowHeight * widget.data.length.clamp(1, 40);
    return (height / widget.rowHeight).ceil().clamp(1, 200);
  }

  int get _targetBuildRows =>
      (_viewportRows * widget.viewportMultiplier).ceil();

  int get _halfBuffer =>
      ((_targetBuildRows - _viewportRows) / 2).ceil().clamp(2, 100);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshState);
    _updateVisibleRows();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshState());
  }

  @override
  void didUpdateWidget(covariant WidgetsTableVirtualized<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshState);
      widget.controller.addListener(_refreshState);
    }
    _updateVisibleRows();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshState());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshState);
    super.dispose();
  }

  void _refreshState() {
    if (_updateVisibleRows() && mounted) setState(() {});
  }

  bool _updateVisibleRows() {
    if (widget.data.isEmpty) return false;

    final rowCount = widget.data.length;
    int nextStart = _rowStart;
    int nextEnd = _rowEnd;

    if (rowCount <= _targetBuildRows) {
      nextStart = 0;
      nextEnd = rowCount;
    } else {
      if (!widget.controller.hasClients) return false;

      final position = widget.controller.position;
      final viewportHeight = position.viewportDimension;
      final currentPixels = position.pixels;
      final totalHeadingHeight = widget.headerHeight + 12;
      final scrollDelta = currentPixels - _scrollPosition;
      _scrollPosition = currentPixels;

      final int cursorStart;
      final int cursorEnd;

      if (widget.isGroup) {
        final double tableTop;
        if (widget.positionTop != null) {
          tableTop = widget.positionTop! - currentPixels;
        } else {
          final tableObject = widget.tableKey?.currentContext
              ?.findRenderObject();
          final viewportObject = position.context.storageContext
              .findRenderObject();
          if (tableObject is! RenderBox ||
              viewportObject is! RenderBox ||
              !tableObject.hasSize ||
              !viewportObject.hasSize) {
            return false;
          }
          tableTop = tableObject
              .localToGlobal(Offset.zero, ancestor: viewportObject)
              .dy;
        }

        cursorStart = ((-tableTop - totalHeadingHeight) / widget.rowHeight)
            .floor();
        cursorEnd =
            ((-tableTop - totalHeadingHeight + viewportHeight) /
                    widget.rowHeight)
                .ceil();
      } else {
        cursorStart = (currentPixels / widget.rowHeight).floor();
        cursorEnd =
            ((currentPixels + viewportHeight - totalHeadingHeight) /
                    widget.rowHeight)
                .ceil();
      }

      if (cursorEnd > 0 && cursorStart < rowCount) {
        final visibleStart = cursorStart.clamp(0, rowCount);
        final visibleEnd = cursorEnd.clamp(visibleStart, rowCount);
        final minOffscreenRows = (_halfBuffer * 0.75).ceil().clamp(
          2,
          _halfBuffer,
        );
        final hasEnoughTopOffscreen =
            (_rowStart == 0) || (visibleStart - _rowStart >= minOffscreenRows);
        final hasEnoughBottomOffscreen =
            (_rowEnd == rowCount) || (_rowEnd - visibleEnd >= minOffscreenRows);

        if (!hasEnoughTopOffscreen ||
            !hasEnoughBottomOffscreen ||
            _rowEnd <= _rowStart) {
          final jumpRows = (scrollDelta.abs() / widget.rowHeight).ceil().clamp(
            0,
            _viewportRows,
          );
          final topBuffer = scrollDelta < 0
              ? (_halfBuffer * 1.5).ceil() + jumpRows
              : (_halfBuffer * 0.5).floor();
          final bottomBuffer = scrollDelta > 0
              ? (_halfBuffer * 1.5).ceil() + jumpRows
              : (_halfBuffer * 0.5).floor();

          int candidateStart = (visibleStart - topBuffer).clamp(0, rowCount);
          int candidateEnd = (visibleEnd + bottomBuffer).clamp(
            candidateStart,
            rowCount,
          );
          if (candidateStart <= _halfBuffer) candidateStart = 0;
          if (rowCount - candidateEnd <= _halfBuffer) candidateEnd = rowCount;

          nextStart = candidateStart;
          nextEnd = candidateEnd;
        }
      }
    }

    if (nextStart == _rowStart && nextEnd == _rowEnd) return false;
    _rowStart = nextStart;
    _rowEnd = nextEnd;
    return true;
  }

  List<DataRow> _buildRows() {
    final countChanged = _rowCount != widget.data.length;
    _rowCount = widget.data.length;

    if (widget.data.isEmpty) {
      _rowStart = 0;
      _rowEnd = 0;
      return const <DataRow>[];
    }

    if (widget.data.length <= _targetBuildRows) {
      _rowStart = 0;
      _rowEnd = widget.data.length;
      return widget.data.map(widget.rowBuilder).toList(growable: false);
    }

    if (!widget.controller.hasClients) {
      return [
        DataRow2(
          key: const ValueKey('table_loader'),
          specificRowHeight: widget.data.length * widget.rowHeight,
          cells: [
            DataCell(
              widget.loaderBuilder?.call() ??
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            ),
            ...List.generate(
              (widget.columnCount - 1).clamp(0, 50),
              (_) => const DataCell(SizedBox.shrink()),
              growable: false,
            ),
          ],
        ),
      ];
    }

    if (countChanged || _rowEnd <= _rowStart) {
      _rowStart = _rowStart.clamp(0, widget.data.length);
      _rowEnd = (_rowStart + _targetBuildRows).clamp(
        _rowStart,
        widget.data.length,
      );
    }

    final start = _rowStart.clamp(0, widget.data.length);
    final end = _rowEnd.clamp(start, widget.data.length);
    final rows = <DataRow>[];

    if (start > 0) {
      rows.add(_buildSpacerRow(start, 'top'));
    }
    for (var index = start; index < end; index++) {
      rows.add(widget.rowBuilder(widget.data[index]));
    }
    final remaining = widget.data.length - end;
    if (remaining > 0) {
      rows.add(_buildSpacerRow(remaining, 'bottom'));
    }

    return rows;
  }

  DataRow2 _buildSpacerRow(int rowCount, String id) {
    return DataRow2(
      key: ValueKey('spacer_$id'),
      specificRowHeight: rowCount * widget.rowHeight,
      cells: List.generate(
        widget.columnCount,
        (_) => const DataCell(SizedBox.shrink()),
        growable: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsTableProxy(
      controller: widget.controller,
      headerHeight: widget.headerHeight,
      rowHeight: widget.rowHeight,
      topOffset: widget.topOffset,
      minHeight: widget.minHeight,
      background: widget.background,
      child: widget.childBuilder(_buildRows()),
    );
  }
}

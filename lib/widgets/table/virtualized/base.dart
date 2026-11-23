import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../proxy.dart';

abstract class WidgetsTableVirtualizedBase<T> extends StatefulWidget {
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
  final Widget Function()? loaderBuilder;
  final double viewportMultiplier;

  const WidgetsTableVirtualizedBase({
    super.key,
    required this.controller,
    required this.data,
    required this.rowBuilder,
    required this.columnCount,
    required this.childBuilder,
    this.headerHeight = AppTheme.tableHeadingRowHeight,
    this.rowHeight = AppTheme.tableDataRowMinHeight,
    this.topOffset = 80,
    this.minHeight = 126.0,
    this.background = AppTheme.panelBg,
    this.loaderBuilder,
    this.viewportMultiplier = 2.5,
  });
}

abstract class WidgetsTableVirtualizedBaseState<T, W extends WidgetsTableVirtualizedBase<T>> extends State<W> {
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

  int get _targetBuildRows => (_viewportRows * widget.viewportMultiplier).ceil();

  int get _halfBuffer => ((_targetBuildRows - _viewportRows) / 2).ceil().clamp(2, 100);

  bool get shouldLateRefresh => true;

  (int rawStart, int rawEnd) computeRawRange(ScrollPosition pos);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshState);
    _updateVisibleRows();

    if (shouldLateRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshState());
    }
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshState);
      widget.controller.addListener(_refreshState);
    }
    _updateVisibleRows();

    if (shouldLateRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshState());
    }
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
    final n = widget.data.length;
    if (n == 0) return false;

    int start = _rowStart;
    int end = _rowEnd;

    if (n <= _targetBuildRows) {
      start = 0;
      end = n;
    } else {
      if (!widget.controller.hasClients) return false;

      final pos = widget.controller.position;
      final dy = pos.pixels - _scrollPosition;
      _scrollPosition = pos.pixels;

      final (rawStart, rawEnd) = computeRawRange(pos);

      if (rawEnd <= 0 || rawStart >= n) return false;

      final visStart = rawStart.clamp(0, n);
      final visEnd = rawEnd.clamp(visStart, n);
      final minBuf = (_halfBuffer * 0.75).ceil().clamp(2, _halfBuffer);

      final okTop = _rowStart == 0 || (visStart - _rowStart >= minBuf);
      final okBot = _rowEnd == n || (_rowEnd - visEnd >= minBuf);

      if (!okTop || !okBot || _rowEnd <= _rowStart) {
        final jump = (dy.abs() / widget.rowHeight).ceil().clamp(0, _viewportRows);
        final lead = (_halfBuffer * 1.5).ceil() + jump;
        final trail = (_halfBuffer * 0.5).floor();

        start = (visStart - (dy < 0 ? lead : trail)).clamp(0, n);
        end = (visEnd + (dy > 0 ? lead : trail)).clamp(start, n);

        if (start <= _halfBuffer) start = 0;
        if (n - end <= _halfBuffer) end = n;
      }
    }

    if (start == _rowStart && end == _rowEnd) return false;
    _rowStart = start;
    _rowEnd = end;
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
                  const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            ...List.generate((widget.columnCount - 1).clamp(0, 50), (_) => const DataCell(SizedBox.shrink()), growable: false),
          ],
        ),
      ];
    }

    if (countChanged || _rowEnd <= _rowStart) {
      _rowStart = _rowStart.clamp(0, widget.data.length);
      _rowEnd = (_rowStart + _targetBuildRows).clamp(_rowStart, widget.data.length);
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
      cells: List.generate(widget.columnCount, (_) => const DataCell(SizedBox.shrink()), growable: false),
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

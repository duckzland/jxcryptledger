import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
// import '../core/log.dart';
import 'state.dart';

mixin MixinsTable<T extends StatefulWidget> on State<T>, MixinsState {
  List<Map<String, dynamic>> tableData = <Map<String, dynamic>>[];
  List<DataColumn> tableColumns = [];

  final GlobalKey tableKey = GlobalKey();

  ScrollController get tableScrollController;
  bool get tableIsGroup => false;

  double get tableHeightOffset => 0.0;
  double get tableHeadingHeightOffset => 12;
  double get tableHeightPercentageFromViewport => 0.8;
  double get tableRowHeight => AppTheme.tableDataRowMinHeight;
  double get tableHeadingHeight => AppTheme.tableHeadingRowHeight;

  int get tableMinimumRowEntries => 5;
  double get tableViewportMultiplier => 2.5;

  int _tableRowStart = 0;
  int _tableRowEnd = 0;
  int _tableRowCount = -1;

  double _scrollPosition = 0.0;

  int get _viewportRows {
    final viewportHeight = tableScrollController.hasClients
        ? tableScrollController.position.viewportDimension
        : states.get('viewport-height', defaultValue: 800.0);
    return (viewportHeight / tableRowHeight).ceil().clamp(1, 200);
  }

  int get _targetBuildRows => (_viewportRows * tableViewportMultiplier).ceil();
  int get _halfBuffer => ((_targetBuildRows - _viewportRows) / 2).ceil().clamp(2, 100);

  @override
  void initState() {
    super.initState();
    tableScrollController.addListener(tableUpdateVisibleRows);
    tableUpdateVisibleRows();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tableUpdateVisibleRows();
    });
  }

  @override
  void dispose() {
    tableScrollController.removeListener(tableUpdateVisibleRows);
    super.dispose();
  }

  List<Map<String, dynamic>> tablePopulateData();

  DataRow tableBuildRow(Map<String, dynamic> row);

  List<DataColumn> tableBuildColumns();

  Widget tableBuildLoader() {
    return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
  }

  List<DataRow> tableBuildRows() {
    final countChanged = _tableRowCount != tableData.length;
    _tableRowCount = tableData.length;

    if (tableData.isEmpty) {
      _tableRowStart = 0;
      _tableRowEnd = 0;
      return const <DataRow>[];
    }

    if (tableData.length <= _targetBuildRows) {
      _tableRowStart = 0;
      _tableRowEnd = tableData.length;
      return tableData.map(tableBuildRow).toList(growable: false);
    }

    if (!tableScrollController.hasClients) {
      return [
        DataRow2(
          key: const ValueKey('table_loader'),
          specificRowHeight: tableData.length * tableRowHeight,
          cells: [
            DataCell(tableBuildLoader()),
            ...List.generate((tableColumns.length - 1).clamp(0, 50), (_) => const DataCell(SizedBox.shrink()), growable: false),
          ],
        ),
      ];
    }

    if (countChanged || _tableRowEnd <= _tableRowStart) {
      _tableRowStart = _tableRowStart.clamp(0, tableData.length);
      _tableRowEnd = (_tableRowStart + _targetBuildRows).clamp(_tableRowStart, tableData.length);
    }

    final start = _tableRowStart.clamp(0, tableData.length);
    final end = _tableRowEnd.clamp(start, tableData.length);
    final rows = <DataRow>[];

    if (start > 0) {
      rows.add(tableBuildSpacerRow(start, 'top'));
    }

    for (var index = start; index < end; index++) {
      rows.add(tableBuildRow(tableData[index]));
    }

    final remaining = tableData.length - end;
    if (remaining > 0) {
      rows.add(tableBuildSpacerRow(remaining, 'bottom'));
    }

    // logln("Generating table rows: ${rows.length} (slice: $start..$end / ${tableData.length})", "TABLE");

    return rows;
  }

  Widget tableBuild();

  DataRow2 tableBuildSpacerRow(int rowCount, String id) {
    return DataRow2(
      key: ValueKey('spacer_$id'),
      specificRowHeight: rowCount * tableRowHeight,
      cells: List.generate(tableColumns.length, (_) => const DataCell(SizedBox.shrink()), growable: false),
    );
  }

  void tableUpdateVisibleRows() {
    if (tableData.isEmpty) return;

    final rowCount = tableData.length;
    int nextStart = _tableRowStart;
    int nextEnd = _tableRowEnd;

    if (rowCount <= _targetBuildRows) {
      nextStart = 0;
      nextEnd = rowCount;
    } else {
      if (!tableScrollController.hasClients) return;

      final position = tableScrollController.position;
      final viewportHeight = position.viewportDimension;
      final totalHeadingHeight = tableHeadingHeight + tableHeadingHeightOffset;

      final currentPixels = position.pixels;
      final scrollDelta = currentPixels - _scrollPosition;
      _scrollPosition = currentPixels;

      final int cursorStart;
      final int cursorEnd;

      if (tableIsGroup) {
        final tableObject = tableKey.currentContext?.findRenderObject();
        final viewportObject = position.context.storageContext.findRenderObject();

        if (tableObject is! RenderBox || viewportObject is! RenderBox || !tableObject.hasSize || !viewportObject.hasSize) {
          return;
        }

        final tableTop = tableObject.localToGlobal(Offset.zero, ancestor: viewportObject).dy;

        cursorStart = ((-tableTop - totalHeadingHeight) / tableRowHeight).floor();
        cursorEnd = ((-tableTop - totalHeadingHeight + viewportHeight) / tableRowHeight).ceil();
      } else {
        cursorStart = (currentPixels / tableRowHeight).floor();
        cursorEnd = ((currentPixels + viewportHeight - totalHeadingHeight) / tableRowHeight).ceil();
      }

      if (cursorEnd > 0 && cursorStart < rowCount) {
        final visibleStart = cursorStart.clamp(0, rowCount);
        final visibleEnd = cursorEnd.clamp(visibleStart, rowCount);

        final minOffscreenRows = (_halfBuffer * 0.75).ceil().clamp(2, _halfBuffer);
        final hasEnoughTopOffscreen = (_tableRowStart == 0) || (visibleStart - _tableRowStart >= minOffscreenRows);
        final hasEnoughBottomOffscreen = (_tableRowEnd == rowCount) || (_tableRowEnd - visibleEnd >= minOffscreenRows);

        if (!hasEnoughTopOffscreen || !hasEnoughBottomOffscreen || _tableRowEnd <= _tableRowStart) {
          final jumpRows = (scrollDelta.abs() / tableRowHeight).ceil().clamp(0, _viewportRows);
          final topBuffer = scrollDelta < 0 ? (_halfBuffer * 1.5).ceil() + jumpRows : (_halfBuffer * 0.5).floor();
          final bottomBuffer = scrollDelta > 0 ? (_halfBuffer * 1.5).ceil() + jumpRows : (_halfBuffer * 0.5).floor();

          int candidateStart = (visibleStart - topBuffer).clamp(0, rowCount);
          int candidateEnd = (visibleEnd + bottomBuffer).clamp(candidateStart, rowCount);

          if (candidateStart <= _halfBuffer) {
            candidateStart = 0;
          }
          if (rowCount - candidateEnd <= _halfBuffer) {
            candidateEnd = rowCount;
          }

          nextStart = candidateStart;
          nextEnd = candidateEnd;
        }
      }
    }

    if (nextStart == _tableRowStart && nextEnd == _tableRowEnd) return;

    _tableRowStart = nextStart;
    _tableRowEnd = nextEnd;
    if (mounted) setState(() {});
  }

  double tableCalculateAdjustedMaxHeight() {
    double maxHeight = states.get('viewport-height', defaultValue: -1.00);

    double suggestedHeight = (tableData.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
    double minimumHeight = (tableMinimumRowEntries * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset + tableHeightOffset;

    if (maxHeight < minimumHeight) {
      return suggestedHeight;
    }

    maxHeight -= tableHeightOffset;
    maxHeight = maxHeight * tableHeightPercentageFromViewport;
    if (maxHeight > 0 && suggestedHeight > maxHeight) {
      maxHeight -= tableHeadingHeight + tableHeadingHeightOffset;
      final rowsFit = (maxHeight / tableRowHeight).floor();

      int clampedRows;
      if (tableData.length >= tableMinimumRowEntries) {
        clampedRows = rowsFit < tableMinimumRowEntries ? tableMinimumRowEntries : rowsFit;
      } else {
        clampedRows = rowsFit;
      }

      if (clampedRows > tableData.length) {
        clampedRows = tableData.length;
      }

      suggestedHeight = clampedRows * tableRowHeight;
    }

    return suggestedHeight;
  }

  double tableCalculateHeight() {
    return (tableData.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'state.dart';

mixin MixinsTable<T extends StatefulWidget> on State<T>, MixinsState {
  List<Map<String, dynamic>> tableData = <Map<String, dynamic>>[];
  List<DataColumn> tableColumns = [];

  double get tableHeightOffset => 0.0;
  double get tableHeadingHeightOffset => 12;
  double get tableHeightPercentageFromViewport => 0.8;
  double get tableRowHeight => AppTheme.tableDataRowMinHeight;
  double get tableHeadingHeight => AppTheme.tableHeadingRowHeight;

  int get tableMinimumRowEntries => 5;

  double tableCalculateAdjustedMaxHeight() {
    double maxHeight = states.get('viewport-height', defaultValue: -1.00);

    final suggestedHeight = (tableData.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
    final minimumHeight = (tableMinimumRowEntries * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset + tableHeightOffset;

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

      return clampedRows * tableRowHeight;
    }

    return suggestedHeight;
  }

  double tableCalculateHeight() {
    return (tableData.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
  }
}

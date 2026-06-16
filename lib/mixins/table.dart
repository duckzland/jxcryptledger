import '../app/theme.dart';
import 'state.dart';

mixin MixinsTable on MixinsState {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  double get tableHeightOffset => 0.0;
  double get tableHeadingHeightOffset => 12;
  double get tableHeightPercentageFromViewport => 0.8;
  double get tableRowHeight => AppTheme.tableDataRowMinHeight;
  double get tableHeadingHeight => AppTheme.tableHeadingRowHeight;

  int tableMinimumRowEntries = 5;

  double tableCalculateAdjustedMaxHeight() {
    double maxHeight = states.get('viewport-height', defaultValue: -1.00);

    double suggestedHeight = (rows.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
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
      if (rows.length >= tableMinimumRowEntries) {
        clampedRows = rowsFit < tableMinimumRowEntries ? tableMinimumRowEntries : rowsFit;
      } else {
        clampedRows = rowsFit;
      }

      if (clampedRows > rows.length) {
        clampedRows = rows.length;
      }

      final maxRows = clampedRows.toDouble();

      suggestedHeight = (maxRows * tableRowHeight);
    }

    return suggestedHeight;
  }

  double tableCalculateHeight() {
    return (rows.length * tableRowHeight) + tableHeadingHeight + tableHeadingHeightOffset;
  }
}

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

class WidgetsSortableColumn extends DataColumn2 {
  WidgetsSortableColumn({
    required Widget label,
    super.tooltip,
    super.numeric = false,
    super.onSort,
    super.size = ColumnSize.M,
    super.fixedWidth,
    super.minWidth,
    super.isResizable = false,
    super.headingRowAlignment,
  }) : super(
         label: onSort != null ? MouseRegion(cursor: SystemMouseCursors.click, child: label) : label,
       );
}

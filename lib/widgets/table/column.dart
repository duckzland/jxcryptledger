import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/rendering.dart';

class WidgetsTableColumn extends DataColumn2 {
  WidgetsTableColumn({
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
         label: WidgetsTableColumnRender(
           child: onSort != null ? MouseRegion(cursor: SystemMouseCursors.click, child: label) : label,
         ),
       );
}

class WidgetsTableColumnRender extends SingleChildRenderObjectWidget {
  const WidgetsTableColumnRender({super.key, required Widget super.child});

  @override
  WidgetsTableColumnRenderElement createRenderObject(BuildContext context) => WidgetsTableColumnRenderElement();
}

class WidgetsTableColumnRenderElement extends RenderProxyBox {}

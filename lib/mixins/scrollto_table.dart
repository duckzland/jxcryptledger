import 'package:flutter/material.dart';

import '../core/scrollto.dart';
import '../app/theme.dart';
import '../core/abstracts/models/with_id.dart';

mixin MixinsScrollToTable<T extends StatefulWidget, K extends CoreModelWithId> {
  ScrollTo get scrollUtil;

  late List<Map<String, dynamic>> rows;
  double scrollToRowHeight = AppTheme.tableDataRowMinHeight;
  String scrollToRowIndexKey = 'uuid';

  void scrollToTableNewRow(K tx) {
    final index = scrollToFindTableRowIndex(tx);
    scrollToTableRowIndex(index);
  }

  int scrollToFindTableRowIndex(K tx) {
    return rows.indexWhere((ltx) => ltx[scrollToRowIndexKey] == tx.uuid);
  }

  void scrollToTableRowIndex(int index) {
    if (index < 0 || index > rows.length) {
      return;
    }

    double offset = 0.0;
    if (index == 0) {
      scrollUtil.toStart();
    } else {
      double currentScrollTop = scrollUtil.controller.offset;
      double currentScrollBottom = currentScrollTop + scrollUtil.controller.position.viewportDimension;
      offset = index * scrollToRowHeight;

      final targetBottom = offset + scrollToRowHeight;
      final isAlreadyVisible = targetBottom > currentScrollTop && offset < currentScrollBottom;
      if (isAlreadyVisible) {
        offset = currentScrollTop;
      }

      offset = offset.clamp(0.0, scrollUtil.controller.position.maxScrollExtent);

      scrollUtil.toOffset(offset);
    }
  }
}

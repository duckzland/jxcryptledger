import 'package:flutter/material.dart';

import '../core/scrollto.dart';
import '../app/theme.dart';
import '../core/abstracts/models/with_id.dart';

mixin MixinsScrollToTable<T extends StatefulWidget, K extends CoreModelWithId> {
  ScrollTo get scrollToUtil;

  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

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
      scrollToUtil.toStart();
    } else {
      double currentScrollTop = scrollToUtil.controller.offset;
      double currentScrollBottom = currentScrollTop + scrollToUtil.controller.position.viewportDimension;
      offset = index * scrollToRowHeight;

      final targetBottom = offset + scrollToRowHeight;
      final isAlreadyVisible = targetBottom > currentScrollTop && offset < currentScrollBottom;
      if (isAlreadyVisible) {
        offset = currentScrollTop;
      }

      offset = offset.clamp(0.0, scrollToUtil.controller.position.maxScrollExtent);

      scrollToUtil.toOffset(offset);
    }
  }
}

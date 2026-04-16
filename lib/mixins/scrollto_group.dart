import 'package:flutter/material.dart';

import '../core/scrollto.dart';
import '../core/abstracts/models/with_id.dart';

mixin MixinsScrollToGroup<T extends StatefulWidget, K extends CoreModelWithId> {
  ScrollTo get scrollUtil;
  double scrollToGroupGetGroupHeight(List<K> txs, double currentWidth);
  double scrollToGroupGetSeparatorHeight();

  void scrollToGroup(String groupKey, Map<String, List<K>> grouped, BuildContext context) {
    if (!scrollUtil.controller.hasClients) {
      return;
    }

    double offset = 0.0;
    double currentWidth = MediaQuery.of(context).size.width;

    if (grouped.keys.first == groupKey) {
      scrollUtil.toStart();
    } else {
      double currentScrollTop = scrollUtil.controller.offset;
      double currentScrollBottom = currentScrollTop + scrollUtil.controller.position.viewportDimension;

      for (var id in grouped.keys) {
        if (id == groupKey) break;

        final txs = grouped[id]!;
        offset += scrollToGroupGetGroupHeight(txs, currentWidth) + scrollToGroupGetSeparatorHeight();
      }

      final targetBottom = offset + scrollToGroupGetGroupHeight(grouped[groupKey]!, currentWidth);
      final isAlreadyVisible = targetBottom > currentScrollTop && offset < currentScrollBottom;

      if (isAlreadyVisible) {
        offset = currentScrollTop;
      }

      scrollUtil.toOffset(offset);
    }
  }

  String? scrollToGroupGetDifferenceKey(Map<String, List<K>> a, Map<String, List<K>> b) {
    final keysA = a.keys.toList();
    final keysB = b.keys.toList();

    for (int i = 0; i < keysA.length; i++) {
      if (keysA[i] != keysB[i] && !keysB.contains(keysA[i])) {
        return keysA[i];
      }

      if (keysA[i] != keysB[i] && keysB.contains(keysA[i]) && a[keysA[i]]?.length != b[keysB[i]]?.length) {
        return keysA[i];
      }
    }

    return null;
  }
}

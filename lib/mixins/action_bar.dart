import 'package:flutter/material.dart';

import '../app/layout.dart';
import '../widgets/action_bar.dart';

mixin MixinsActionBar<T extends StatefulWidget> on State<T> {

  Widget? buildLeftAction() => null;
  Widget? buildMainAction() => null;
  Widget? buildRightAction() => null;

  void registerBars(String? title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (title != null) {
        AppLayout.setTitle?.call(title);
      }

      final left = buildLeftAction();
      final main = buildMainAction();
      final right = buildRightAction();

      if (left != null || main != null || right != null) {
        AppLayout.setActions?.call(WidgetsActionBar(leftActions: left, mainActions: main, rightActions: right));
      }
    });
  }

  void removeBars() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setActions?.call(null);
    });
  }
}

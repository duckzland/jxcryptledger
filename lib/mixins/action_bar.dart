import 'package:flutter/material.dart';

import '../app/layout.dart';
import '../widgets/action_bar.dart';

mixin MixinsActionBar<T extends StatefulWidget> on State<T> {
  Widget? actionbarLeftAction() => null;
  Widget? actionbarMainAction() => null;
  Widget? actionbarRightAction() => null;

  void actionbarRegister(String? title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (title != null) {
        AppLayout.setTitle?.call(title);
      }

      final left = actionbarLeftAction();
      final main = actionbarMainAction();
      final right = actionbarRightAction();

      if (left != null || main != null || right != null) {
        AppLayout.setActions?.call(WidgetsActionBar(leftActions: left, mainActions: main, rightActions: right));
      }
    });
  }

  void actionbarRemove() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setActions?.call(null);
    });
  }
}

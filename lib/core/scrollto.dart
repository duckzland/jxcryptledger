import 'dart:async';

import 'package:flutter/material.dart';

class ScrollTo {
  final ScrollController controller = ScrollController();
  Timer? _debounce;

  ScrollTo();

  void toOffset(double offset) {
    if (!controller.hasClients) {
      return;
    }
    ;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.jumpTo(offset);
      });
    });
  }

  void toStart() {
    toOffset(0);
  }

  void toEnd() {
    if (!controller.hasClients) {
      return;
    }

    // Need to calculate the maxscroll at the very late!
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.jumpTo(controller.position.maxScrollExtent);
      });
    });
  }

  void dispose() {
    controller.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/state.dart';

class ScrollTo {
  String? storeKey;

  late ScrollController controller;
  Timer? _debounce;

  ScrollTo([this.storeKey]) {
    controller = ScrollController(initialScrollOffset: AppState.instance.get(storeKey ?? "", defaultValue: 0.0));

    if (storeKey != null) {
      controller.addListener(storeOffset);
    }
  }

  void storeOffset() {
    if (storeKey != null) {
      AppState.instance.set(storeKey!, controller.offset);
    }
  }

  void toOffset(double offset) {
    if (!controller.hasClients) {
      return;
    }
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
    if (storeKey != null) {
      controller.removeListener(storeOffset);
    }
    _debounce?.cancel();
    controller.dispose();
  }
}

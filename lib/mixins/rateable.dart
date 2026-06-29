import 'dart:async';

import 'package:flutter/material.dart';

import '../app/exceptions.dart';
import '../core/locator.dart';
import '../core/utils.dart';
import '../features/rates/controller.dart';
import '../widgets/notify.dart';

mixin MixinsRateable<T extends StatefulWidget> on State<T> {
  late void Function(String value, String helperText)? rateableStateUpdater;
  final List<(int source, int target)> rateableTemporary = [];

  StreamSubscription? _emitter;
  bool rateableIsTemporary = true;
  bool rateableWithField = true;
  bool rateableForceFetch = true;
  String rateableDefaultHelper = "e.g., 10.5";

  int? rateableSource;
  int? rateableTarget;
  double? rateableValue;
  String? rateableAmount;

  bool get rateableAllow => (rateableSource ?? 0) > 0 && (rateableTarget ?? 0) > 0;
  RatesController get rateableController => locator<RatesController>();

  void rateableGetCallback() {}

  @override
  void initState() {
    super.initState();
    rateableSource = null;
    rateableTarget = null;
    rateableAmount = null;
    rateableValue = null;
    rateableStateUpdater = null;
    rateableController.init();
    rateableController.addListener(rateableUpdateRate);
  }

  @override
  void dispose() {
    rateableStateUpdater = null;
    rateableController.removeListener(rateableUpdateRate);
    if (rateableIsTemporary) {
      rateableCleanTemporary();
    }
    _emitter?.cancel();
    super.dispose();
  }

  void rateableUpdateRate() {
    if (!mounted || (rateableWithField && rateableStateUpdater == null)) {
      return;
    }

    rateableGetRate(silent: true);
  }

  void rateableGetRate({bool refresh = true, bool reversed = false, bool silent = false}) {
    try {
      final int source = rateableSource ?? 0;
      final int target = rateableTarget ?? 0;

      if (source < 0 || target < 0) {
        return;
      }

      final rate = rateableController.getStoredRate(reversed ? target : source, reversed ? source : target, throwable: true);
      if (rate == -9999) {
        rateableController.addQueue(source, target, force: rateableForceFetch);
        if (rateableIsTemporary) {
          rateableTemporary.add((source, target));
        }
        return;
      }

      rateableAmount = Utils.formatSmartDouble(rate).replaceAll(",", "");
      rateableValue = rate;

      rateableGetCallback.call();

      if (rateableStateUpdater != null) {
        rateableStateUpdater?.call(rateableAmount ?? "", rateableDefaultHelper);
        rateableStateUpdater = null;
      }

      if (refresh && mounted) {
        setState(() {});
      }
    } catch (e) {
      rateableStateUpdater?.call("", rateableDefaultHelper);
      rateableStateUpdater = null;

      if (!silent && e is NetworkingException) {
        widgetsNotifyError(e.userMessage);
      }
    }
  }

  Future<void> rateableCleanTemporary() async {
    final needToRemove = [...rateableTemporary];
    rateableTemporary.clear();
    for (final (source, target) in needToRemove) {
      await rateableController.deleteById(source, target);
      await rateableController.deleteById(target, source);
    }
  }
}

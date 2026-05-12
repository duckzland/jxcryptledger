import 'package:flutter/material.dart';

import '../core/locator.dart';
import '../core/utils.dart';
import '../features/rates/controller.dart';

mixin MixinsRates<T extends StatefulWidget> on State<T> {
  late void Function(String value, String helperText)? ratesStateUpdater;
  final List<(int source, int target)> ratesTemporary = [];

  bool ratesIsTemporary = true;
  String rateDefaultHelper = "e.g., 10.5";

  int? ratesSource;
  int? ratesTarget;
  String? ratesAmount;

  bool get ratesAllow => (ratesSource ?? 0) > 0 && (ratesTarget ?? 0) > 0;
  RatesController get ratesController => locator<RatesController>();

  @override
  void initState() {
    super.initState();
    ratesSource = null;
    ratesTarget = null;
    ratesAmount = null;
    ratesStateUpdater = null;
    ratesController.addListener(ratesUpdated);
  }

  @override
  void dispose() {
    ratesStateUpdater = null;
    ratesController.removeListener(ratesUpdated);
    if (ratesIsTemporary) {
      ratesCleanTemporary();
    }
    super.dispose();
  }

  void ratesUpdated() {
    if (!mounted || ratesStateUpdater == null) {
      return;
    }

    ratesGetRate();
  }

  void ratesGetRate() {
    try {
      final int source = ratesSource ?? 0;
      final int target = ratesTarget ?? 0;

      if (source < 0 || target < 0) {
        return;
      }

      final rate = ratesController.getStoredRate(source, target);
      if (rate == -9999) {
        ratesController.addQueue(source, target);
        if (ratesIsTemporary) {
          ratesTemporary.add((source, target));
        }
        return;
      }
      if (mounted) {
        ratesAmount = Utils.formatSmartDouble(rate).replaceAll(",", "");
        if (ratesStateUpdater != null) {
          ratesStateUpdater?.call(ratesAmount ?? "", rateDefaultHelper);
          ratesStateUpdater = null;
        }
        setState(() {});
      }
    } catch (e) {
      // Do something to process the error message?
    }
  }

  Future<void> ratesCleanTemporary() async {
    for (final (source, target) in ratesTemporary) {
      await ratesController.delete(source, target);
      await ratesController.delete(target, source);
    }
    ratesTemporary.clear();
  }
}

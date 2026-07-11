import 'package:flutter/material.dart';

import '../../../../core/runtime/locator.dart';
import '../../../../mixins/actionable.dart';
import '../../../../widgets/button.dart';
import '../../../../widgets/dialogs/show_form.dart';
import '../../../watchboard/panels/controller.dart';
import '../../../watchboard/panels/form.dart';
import '../../../watchboard/panels/model.dart';
import '../../../watchers/controller.dart';
import '../../../watchers/form.dart';
import '../../../watchers/model.dart';
import '../../model.dart';

class TransactionsWidgetsButtonsLinkable extends StatelessWidget with MixinsActionable {
  final BuildContext parentContext;
  final int srid;
  final int rrid;
  final List<TransactionsModel> txs;
  final double rate;
  final double balance;

  const TransactionsWidgetsButtonsLinkable({
    super.key,
    required this.parentContext,
    required this.srid,
    required this.rrid,
    required this.txs,
    required this.rate,
    required this.balance,
  });

  WatchersController get wxController => locator<WatchersController>();
  PanelsController get pxController => locator<PanelsController>();

  @override
  Widget build(BuildContext context) {
    if (srid == rrid) {
      return SizedBox.shrink();
    }

    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = const EdgeInsets.all(0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        AnimatedBuilder(
          animation: pxController,
          builder: (context, _) {
            final linkedPanel = pxController.getLinked("active-screen-$srid-$rrid");
            return WidgetsDialogsShowForm(
              key: const Key("add-watchboard-button"),
              icon: Icons.candlestick_chart_outlined,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: linkedPanel == null ? "Add new watchboard" : "Edit watchboard",
              persistBg: true,
              evaluator: _evaluatorWatchboard,
              buildForm: _formWatchboard,
            );
          },
        ),

        AnimatedBuilder(
          animation: wxController,
          builder: (context, _) {
            final linkedWatcher = wxController.getLinked("active-screen-$srid-$rrid");
            return WidgetsDialogsShowForm(
              key: const Key("add-watcher-button"),
              icon: Icons.add_alarm,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: linkedWatcher == null ? "Add new watcher" : "Edit watcher",
              persistBg: true,
              evaluator: _evaluatorWatcher,
              buildForm: _formWatcher,
            );
          },
        ),
      ],
    );
  }

  void _evaluatorWatchboard(WidgetsButtonState s) {
    final linkedPanel = pxController.getLinked("active-screen-$srid-$rrid");
    if (linkedPanel == null) {
      s.normal();
    } else {
      s.action();
    }
  }

  void _evaluatorWatcher(WidgetsButtonState s) {
    final linkedWatcher = wxController.getLinked("active-screen-$srid-$rrid");
    if (linkedWatcher == null) {
      s.normal();
    } else {
      linkedWatcher.isSpent ? s.error() : s.action();
    }
  }

  Widget _formWatchboard(BuildContext dialogContext) {
    final linkedPanel = pxController.getLinked("active-screen-$srid-$rrid");
    return PanelsForm(
      initialData: linkedPanel,
      initialSrId: linkedPanel == null ? srid : null,
      initialRrId: linkedPanel == null ? rrid : null,
      initialSrAmount: linkedPanel == null ? balance : null,
      linkedToTx: "active-screen-$srid-$rrid",
      onSave: (e) => actionableFormSave<PanelsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: linkedPanel == null ? "Created watchboard entry." : "Watchboard entry updated",
        error: e,
      ),
    );
  }

  Widget _formWatcher(BuildContext dialogContext) {
    final linkedWatcher = wxController.getLinked("active-screen-$srid-$rrid");
    return WatchersForm(
      initialData: linkedWatcher,
      initialSrId: linkedWatcher == null ? srid : null,
      initialRrId: linkedWatcher == null ? rrid : null,
      initialRate: linkedWatcher == null ? rate : null,
      linkedToTx: "active-screen-$srid-$rrid",
      onSave: (e) => actionableFormSave<WatchersModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: linkedWatcher == null ? "Created rate watcher." : "Rate watcher updated",
        error: e,
      ),
    );
  }
}

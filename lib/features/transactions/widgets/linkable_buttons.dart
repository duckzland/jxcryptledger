import 'package:flutter/material.dart';

import '../../../core/runtime/locator.dart';
import '../../../mixins/actionable.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../watchboard/panels/controller.dart';
import '../../watchboard/panels/form.dart';
import '../../watchboard/panels/model.dart';
import '../../watchers/controller.dart';
import '../../watchers/form.dart';
import '../../watchers/model.dart';
import '../model.dart';

class TransactionsWidgetsLinkableButtons extends StatelessWidget with MixinsActionable {
  final int srid;
  final int rrid;
  final List<TransactionsModel> txs;
  final double rate;
  final double balance;

  const TransactionsWidgetsLinkableButtons({
    super.key,
    required this.srid,
    required this.rrid,
    required this.txs,
    required this.rate,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    if (srid == rrid) {
      return SizedBox.shrink();
    }

    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = const EdgeInsets.all(0);

    final WatchersController wxController = locator<WatchersController>();
    final PanelsController pxController = locator<PanelsController>();

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
              evaluator: (s) {
                if (linkedPanel == null) {
                  s.normal();
                } else {
                  s.action();
                }
              },
              buildForm: (dialogContext) {
                return PanelsForm(
                  initialData: linkedPanel,
                  initialSrId: linkedPanel == null ? srid : null,
                  initialRrId: linkedPanel == null ? rrid : null,
                  initialSrAmount: linkedPanel == null ? balance : null,
                  linkedToTx: "active-screen-$srid-$rrid",
                  onSave: (e) => actionableFormSave<PanelsModel>(
                    context,
                    dialogContext: dialogContext,
                    successMessage: linkedPanel == null ? "Created watchboard entry." : "Watchboard entry updated",
                    error: e,
                  ),
                );
              },
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
              evaluator: (s) {
                if (linkedWatcher == null) {
                  s.normal();
                } else {
                  linkedWatcher.isSpent ? s.error() : s.action();
                }
              },
              buildForm: (dialogContext) {
                return WatchersForm(
                  initialData: linkedWatcher,
                  initialSrId: linkedWatcher == null ? srid : null,
                  initialRrId: linkedWatcher == null ? rrid : null,
                  initialRate: linkedWatcher == null ? rate : null,
                  linkedToTx: "active-screen-$srid-$rrid",
                  onSave: (e) => actionableFormSave<WatchersModel>(
                    context,
                    dialogContext: dialogContext,
                    successMessage: linkedWatcher == null ? "Created rate watcher." : "Rate watcher updated",
                    error: e,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

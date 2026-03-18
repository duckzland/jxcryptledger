import 'package:flutter/material.dart';

import '../../../widgets/button.dart';
import '../../mixins/actions.dart';
import '../../widgets/dialogs/alert.dart';
import '../../widgets/dialogs/show_form.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

class WatchersButtons extends StatelessWidget with MixinsActions {
  final WatchersModel tx;
  final WatchersController wxController;
  final void Function() onAction;

  const WatchersButtons({super.key, required this.tx, required this.wxController, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsDialogsShowForm(
          key: Key("edit-button-${tx.wid}"),
          icon: Icons.edit,
          initialState: WidgetsButtonActionState.normal,
          tooltip: "Edit this rate watcher",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          buildForm: (BuildContext dialogContext) {
            return WatchersForm(
              initialData: tx,
              linkedToTx: tx.meta["txLink"],
              onSave: (e) => doFormSave<WatchersModel>(
                context,
                dialogContext: dialogContext,
                onComplete: onAction,
                successMessage: "Rate watcher updated.",
                error: e,
              ),
            );
          },
        ),
        WidgetsDialogsAlert<WatchersModel>(
          key: Key("delete-button-${tx.wid}"),
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete this rate watcher",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          dialogTitle: "Delete Rate Watcher",
          dialogMessage:
              "This will delete this rate watcher.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Delete",
          actionData: tx,
          actionCallback: wxController.delete,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "Rate watcher deleted.",
        ),
        WidgetsButton(
          key: Key("test-button-${tx.wid}"),
          icon: Icons.arrow_forward,
          initialState: WidgetsButtonActionState.action,
          tooltip: "Test sending notification",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          onPressed: (_) => wxController.sendNotification(tx),
        ),
      ],
    );
  }
}

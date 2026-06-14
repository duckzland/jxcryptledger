import 'package:flutter/material.dart';

import '../../../widgets/button.dart';
import '../../mixins/actionable.dart';
import '../../widgets/dialogs/alert.dart';
import 'controller.dart';
import 'model.dart';

class ArchivesButtons extends StatelessWidget with MixinsActionable {
  final ArchivesModel tx;
  final ArchivesController wxController;
  final void Function() onAction;

  const ArchivesButtons({super.key, required this.tx, required this.wxController, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsDialogsAlert<ArchivesModel>(
          key: Key("restore-button-${tx.aid}"),
          icon: Icons.restore,
          initialState: WidgetsButtonActionState.action,
          tooltip: "Restore archived ${tx.typeText} data",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          dialogTitle: "Restore ${tx.typeText} Archive",
          dialogMessage:
              "Restoring this archive will replace all current ${tx.typeText} data.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Restore",
          actionData: tx,
          actionCallback: wxController.restoreData,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.typeText} archive restored successfully.",
        ),
        WidgetsDialogsAlert<ArchivesModel>(
          key: Key("delete-button-${tx.aid}"),
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete archived ${tx.typeText} data",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          dialogTitle: "Delete ${tx.typeText} Archive",
          dialogMessage:
              "Deleting this archive will permanently remove the ${tx.typeText} archived data.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Delete",
          actionData: tx,
          actionCallback: wxController.remove,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.typeText} archive deleted successfully.",
        ),
      ],
    );
  }
}

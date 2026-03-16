import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../widgets/button.dart';
import '../../../widgets/notify.dart';
import '../../widgets/dialogs/alert.dart';
import '../../widgets/dialogs/show_form.dart';
import '../cryptos/controller.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

class WatchersButtons extends StatelessWidget {
  final WatchersModel tx;
  final void Function() onAction;

  CryptosController get _cryptosController => locator<CryptosController>();
  WatchersController get _wxController => locator<WatchersController>();

  const WatchersButtons({super.key, required this.tx, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsDialogsShowForm(
          key: Key("edit-button-${tx.wid}"),
          icon: Icons.edit,
          tooltip: "Edit this rate watcher",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          evaluator: (s) {
            _cryptosController.hasAny() ? s.normal() : s.disable();
          },
          buildForm: (BuildContext dialogContext) {
            return WatchersForm(
              initialData: tx,
              linkedToTx: tx.meta["txLink"],
              onSave: (e) async {
                if (e == null) {
                  Navigator.pop(dialogContext);
                  onAction();
                  String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
                  String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

                  widgetsNotifySuccess("$sourceSymbol to $targetSymbol rate watcher updated.");
                  return;
                }

                if (e is ValidationException) {
                  widgetsNotifyError(e.userMessage, ctx: context);
                  return;
                }

                widgetsNotifyError(e.toString(), ctx: context);
              },
            );
          },
        ),
        WidgetsDialogsAlert(
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
          onPressed: (dialogContext) async {
            try {
              await _wxController.delete(tx);

              Navigator.pop(dialogContext);
              onAction();

              String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
              String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

              widgetsNotifySuccess("$sourceSymbol to $targetSymbol rate watcher deleted.");
            } on ValidationException catch (e) {
              widgetsNotifyError(e.userMessage);
            } catch (e) {
              widgetsNotifyError(e.toString());
            }
          },
        ),
        WidgetsButton(
          key: Key("test-button-${tx.wid}"),
          icon: Icons.arrow_forward,
          initialState: WidgetsButtonActionState.action,
          tooltip: "Test sending notification",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          onPressed: (_) => _wxController.sendNotification(tx),
        ),
      ],
    );
  }
}

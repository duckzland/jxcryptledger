import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../widgets/button.dart';
import '../../../widgets/notify.dart';
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

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete Watcher"),
            content: const Text(
              "This will delete this watcher.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Delete',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _wxController.delete(tx);

                    Navigator.pop(dialogContext);
                    onAction();

                    String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
                    String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

                    widgetsNotifySuccess("$sourceSymbol to $targetSymbol watcher deleted.");
                  } on ValidationException catch (e) {
                    widgetsNotifyError(e.userMessage);
                  } catch (e) {
                    widgetsNotifyError(e.toString());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: WatchersForm(
            initialData: tx,
            onSave: (e) async {
              if (e == null) {
                Navigator.pop(dialogContext);
                onAction();
                String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
                String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

                widgetsNotifySuccess("$sourceSymbol to $targetSymbol watcher updated.");
                return;
              }

              if (e is ValidationException) {
                widgetsNotifyError(e.userMessage, ctx: context);
                return;
              }

              widgetsNotifyError(e.toString(), ctx: context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsButton(
          key: Key("edit-button-${tx.wid}"),
          icon: Icons.edit,
          tooltip: "Edit this watcher",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          onPressed: (_) => _showEditDialog(context),
          evaluator: (s) {
            _cryptosController.hasAny() ? s.normal() : s.disable();
          },
        ),
        WidgetsButton(
          key: Key("delete-button-${tx.wid}"),
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete this watcher",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          onPressed: (_) => _showDeleteDialog(context),
        ),
      ],
    );
  }
}

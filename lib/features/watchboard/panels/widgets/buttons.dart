import 'package:flutter/material.dart';

import '../../../../app/exceptions.dart';
import '../../../../widgets/button.dart';
import '../../../../widgets/dialogs/alert.dart';
import '../../../../widgets/dialogs/show_form.dart';
import '../../../../widgets/notify.dart';
import '../../../watchers/form.dart';
import '../../../watchers/model.dart';
import '../form.dart';
import '../model.dart';

class PanelsWidgetsButtons extends StatelessWidget {
  final PanelsModel tix;
  final WatchersModel? linkedWatcher;
  final void Function() onAction;
  final void Function() onDelete;

  const PanelsWidgetsButtons({super.key, required this.tix, required this.linkedWatcher, required this.onAction, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final wix = linkedWatcher;

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsDialogsShowForm(
          icon: Icons.add_alarm,
          initialState: WidgetsButtonActionState.action,
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          tooltip: wix == null ? "Add new watchboard" : "Edit watchboard",
          evaluator: (s) {
            if (wix == null) {
              s.normal();
            } else {
              wix.isSpent() ? s.error() : s.action();
            }
          },
          buildForm: (dialogContext) {
            return WatchersForm(
              initialData: wix,
              initialSrId: wix == null ? tix.srId : null,
              initialRrId: wix == null ? tix.rrId : null,
              initialRate: wix == null ? tix.rate : null,
              linkedToTx: "panels-${tix.tid}",
              onSave: (e) async {
                if (e == null) {
                  Navigator.pop(dialogContext);

                  widgetsNotifySuccess(wix == null ? "Created notification watcher." : "Notification watcher updated");

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

        WidgetsDialogsShowForm(
          key: Key("edit-button-${tix.tid}"),
          icon: Icons.edit,
          tooltip: "Edit this watchboard",
          initialState: WidgetsButtonActionState.normal,
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          buildForm: (dialogContext) {
            return PanelsForm(
              initialData: tix,
              linkedToTx: tix.meta["txLink"],
              onSave: (e) async {
                if (e == null) {
                  Navigator.pop(dialogContext);
                  onAction();
                  widgetsNotifySuccess("watchboard panel updated.");
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
          key: Key("delete-button-${tix.tid}"),
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete this watchboard",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          dialogTitle: "Delete Watchboard",
          dialogMessage: "This will delete this watchboard.\nThis action cannot be undone.",
          dialogConfirmLabel: "Delete",
          onPressed: (dialogContext) async {
            try {
              onDelete();
              Navigator.pop(dialogContext);
              widgetsNotifySuccess("Watchboard panel deleted.");
            } on ValidationException catch (e) {
              widgetsNotifyError(e.userMessage);
            } catch (e) {
              widgetsNotifyError(e.toString());
            }
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/exceptions.dart';
import '../../../../core/locator.dart';
import '../../../../widgets/button.dart';
import '../../../../widgets/notify.dart';
import '../../../cryptos/controller.dart';
import '../../../watchers/controller.dart';
import '../../../watchers/form.dart';
import '../../../watchers/model.dart';
import '../controller.dart';
import '../form.dart';
import '../model.dart';

class TickersWidgetsButtons extends StatefulWidget {
  final PanelsModel tix;
  final void Function() onAction;

  const TickersWidgetsButtons({super.key, required this.tix, required this.onAction});

  @override
  State<TickersWidgetsButtons> createState() => _TickersWidgetsButtonsState();
}

class _TickersWidgetsButtonsState extends State<TickersWidgetsButtons> {
  CryptosController get _cryptosController => locator<CryptosController>();
  PanelsController get _tixController => locator<PanelsController>();

  late final WatchersController _wxController;

  WatchersModel? _linkedWatcher;

  @override
  void initState() {
    super.initState();
    _wxController = locator<WatchersController>();
    _wxController.addListener(_onControllerChanged);

    _linkedWatcher = _wxController.getLinked("panels-${widget.tix.tid}");
  }

  @override
  void dispose() {
    _wxController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _showAddWatcherDialog() {
    final tix = widget.tix;
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Center(
            child: WatchersForm(
              initialData: _linkedWatcher,
              initialSrId: _linkedWatcher == null ? tix.srId : null,
              initialRrId: _linkedWatcher == null ? tix.rrId : null,
              initialRate: _linkedWatcher == null ? tix.rate : null,
              linkedToTx: "panels-${tix.tid}",
              onSave: (e) async {
                if (e == null) {
                  Navigator.pop(dialogContext);

                  if (_linkedWatcher == null) {
                    widgetsNotifySuccess("Created notification watcher.");
                  } else {
                    widgetsNotifySuccess("Notification watcher updated");
                  }

                  setState(() {
                    _linkedWatcher = _wxController.getLinked("panels-${tix.tid}");
                  });
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
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final tix = widget.tix;
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete Panel"),
            content: const Text(
              "This will delete this panel.\n"
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
                    await _tixController.delete(tix);

                    Navigator.pop(dialogContext);
                    widget.onAction();

                    String sourceSymbol = _cryptosController.getSymbol(tix.srId) ?? "";
                    String targetSymbol = _cryptosController.getSymbol(tix.rrId) ?? "";

                    widgetsNotifySuccess("${tix.srAmount} $sourceSymbol to $targetSymbol panel deleted.");
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
    final tix = widget.tix;
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: PanelsForm(
            initialData: tix,
            onSave: (e) async {
              if (e == null) {
                Navigator.pop(dialogContext);
                widget.onAction();
                String sourceSymbol = _cryptosController.getSymbol(tix.srId) ?? "";
                String targetSymbol = _cryptosController.getSymbol(tix.rrId) ?? "";

                widgetsNotifySuccess("${tix.srAmount} $sourceSymbol to $targetSymbol panel updated.");
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
    final tix = widget.tix;
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsButton(
          icon: Icons.add_alarm,
          initialState: WidgetsButtonActionState.action,
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          tooltip: _linkedWatcher == null ? "Add new watchboard" : "Edit watchboard",
          evaluator: (s) {
            if (_linkedWatcher == null) {
              s.normal();
            } else {
              _linkedWatcher!.isSpent() ? s.error() : s.action();
            }
          },
          onPressed: (_) {
            _showAddWatcherDialog();
          },
        ),

        WidgetsButton(
          key: Key("edit-button-${tix.tid}"),
          icon: Icons.edit,
          tooltip: "Edit this watchboard",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 16,
          minimumSize: const Size(34, 34),
          onPressed: (_) => _showEditDialog(context),
          evaluator: (s) {
            _cryptosController.hasAny() ? s.normal() : s.disable();
          },
        ),
        WidgetsButton(
          key: Key("delete-button-${tix.tid}"),
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete this watchboard",
          padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
          iconSize: 18,
          minimumSize: const Size(34, 34),
          onPressed: (_) => _showDeleteDialog(context),
        ),
      ],
    );
  }
}

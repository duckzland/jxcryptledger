import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/notify.dart';
import '../../widgets/panel.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../cryptos/controller.dart';
import 'buttons.dart';
import 'controller.dart';
import 'form.dart';

class WatchersPage extends StatefulWidget {
  const WatchersPage({super.key});

  @override
  State<WatchersPage> createState() => _WatchersPageState();
}

class _WatchersPageState extends State<WatchersPage> {
  late final WatchersController _wxController;
  final CryptosController _cryptosController = locator<CryptosController>();

  @override
  void initState() {
    super.initState();
    _wxController = locator<WatchersController>();
    _wxController.load();
    _wxController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);

    _changePageTitle("Rate Watchers");
  }

  @override
  void dispose() {
    _wxController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);

    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _changePageTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
    });
  }

  void _showAddWatcherDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: _buildForm(dialogContext)),
      ),
    );
  }

  Future<void> _showRestartDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Restart Rate Watchers"),
            content: const Text(
              "This will restart all rate watchers by setting sent to 0.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Restart',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _wxController.restart();

                    Navigator.pop(dialogContext);
                  } catch (e) {
                    widgetsNotifyError("Failed to import rate watchers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cryptosController.hasAny()) {
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding rate watcher.')),
        ],
      );
    }

    if (_wxController.items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
              title: "Add Rate Watcher",
              addTitle: "Add New",
              addTooltip: "Create new rate watcher entry",
              addEvaluator: () => _cryptosController.hasAny(),
              importTitle: "Import",
              importTooltip: "Import rate watchers to database",
              importEvaluator: () => true,
              importCallback: (json) async => await _wxController.importDatabase(json),
              addForm: _buildForm,
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 20, children: [_buildDatabaseAction()]),
                  ),
                ),
                _buildAction(),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext dialogContext) {
    return Center(
      child: WatchersForm(
        onSave: (e) async {
          if (e == null) {
            Navigator.pop(dialogContext);
            return;
          }

          if (e is ValidationException) {
            widgetsNotifyError(e.userMessage, ctx: context);
            return;
          }

          widgetsNotifyError(e.toString(), ctx: context);
        },
      ),
    );
  }

  Widget _buildAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsButton(
            key: Key("restart-button-batch"),
            icon: Icons.refresh,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.warning,
            tooltip: "Restart all rate watchers",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showRestartDialog(context),
            evaluator: (s) {
              if (!_wxController.hasRestartable()) {
                s.disable();
              } else {
                s.warning();
              }
            },
          ),
          WidgetsButton(
            icon: Icons.add_alarm,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.action,
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "Add new rate watcher",
            evaluator: (s) => s.action(),
            onPressed: (_) {
              _showAddWatcherDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsDialogsImport(
            key: Key("import-button-batch"),
            tooltip: "Import rate watchers to database",
            showDialogBeforeImport: true,
            onImport: (String json) async {
              await _wxController.importDatabase(json);
            },
            evaluator: (s) {},
          ),
          WidgetsDialogsExport(
            key: const Key("export-button-batch"),
            tooltip: "Export rate watchers from database",
            suggestedPrefix: "wix_",
            onExport: _wxController.exportDatabase,
            evaluator: (s) {
              if (_wxController.isEmpty()) {
                s.disable();
              } else {
                s.action();
              }
            },
          ),
          WidgetsDialogsReset(
            key: const Key("reset-button-batch"),
            tooltip: "Delete All Rate Watcher",
            dialogTitle: "Delete All Transactions",
            dialogMessage:
                "This will delete all rate watcher.\n"
                "This action cannot be undone.",
            onWipe: _wxController.deleteAll,
            evaluator: (s) {
              if (_wxController.isEmpty()) {
                s.disable();
              } else {
                s.error();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return WidgetsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              headingRowHeight: AppTheme.tableHeadingRowHeight,
              dataRowHeight: AppTheme.tableDataRowMinHeight,
              showCheckboxColumn: false,
              isHorizontalScrollBarVisible: false,
              columns: const [
                DataColumn(label: Text("From")),
                DataColumn(label: Text("To")),
                DataColumn(label: Text("Rate")),
                DataColumn(label: Text("Sent")),
                DataColumn(label: Text("Limit")),
                DataColumn(label: Text("Duration")),
                DataColumn(label: Text("Action")),
              ],
              rows: _wxController.items.map((w) {
                final srSymbol = _cryptosController.getSymbol(w.srId) ?? "Unknown";
                final rrSymbol = _cryptosController.getSymbol(w.rrId) ?? "Unknown";
                return DataRow(
                  cells: [
                    DataCell(Text(srSymbol)),
                    DataCell(Text(rrSymbol)),
                    DataCell(Text(w.rates.toString())),
                    DataCell(Text(w.sent.toString())),
                    DataCell(Text(w.limit.toString())),
                    DataCell(Text("${w.duration}m")),
                    DataCell(
                      WatchersButtons(
                        tx: w,
                        onAction: () {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

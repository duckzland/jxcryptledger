import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../../widgets/button.dart';
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

    _changePageTitle("Notification Watchers");
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
            title: const Text("Restart Watchers"),
            content: const Text(
              "This will restart all watchers by setting sent to 0.\n"
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
                    widgetsNotifyError("Failed to import watchers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete All Watcher"),
            content: const Text(
              "This will delete all watcher.\n"
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
                    await _wxController.deleteAll();

                    Navigator.pop(dialogContext);

                    widgetsNotifySuccess("All watchers deleted.");
                  } catch (e) {
                    widgetsNotifyError("Failed to delete watchers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Import Watcher"),
            content: const Text(
              "This will erase all existing watcher before inserting new data from the selected file.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Import',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _showImportFileSelector();

                    Navigator.pop(dialogContext);
                  } catch (e) {
                    widgetsNotifyError("Failed to import watchers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportFileSelector() async {
    final json = await _wxController.exportDatabase();
    if (json.isEmpty) {
      widgetsNotifyError("Failed to export database.");
      return;
    }

    final suggestedName = "wxs_${DateTime.now().millisecondsSinceEpoch}.json";
    final saveLocation = await getSaveLocation(suggestedName: suggestedName, confirmButtonText: "Save");

    if (saveLocation == null || saveLocation.path.isEmpty) {
      widgetsNotifyError("Export cancelled.");
      return;
    }

    try {
      final file = File(saveLocation.path);
      await file.writeAsString(json);
      widgetsNotifySuccess("Database exported successfully.");
    } catch (e) {
      logln("Failed to save export file: $e");
      widgetsNotifyError("Failed to save exported file.");
    }
  }

  Future<void> _showImportFileSelector() async {
    try {
      final typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        widgetsNotifyError("No file selected.");
        return;
      }

      final json = await file.readAsString();
      await _wxController.importDatabase(json);

      widgetsNotifySuccess("Database imported successfully.");
    } on ValidationException catch (e) {
      widgetsNotifyError(e.userMessage);
    } catch (e) {
      logln("Import failed: $e");
      widgetsNotifyError("Import failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cryptosController.hasAny()) {
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding notification watcher.'),
          ),
        ],
      );
    }

    if (_wxController.items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
              title: "Add Watcher",
              addTitle: "Add New",
              addTooltip: "Create new watcher entry",
              addEvaluator: () => _cryptosController.hasAny(),
              importTitle: "Import",
              importTooltip: "Import watchers to database",
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
                const Expanded(child: SizedBox()),
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
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsButton(
            key: Key("import-button-batch"),
            icon: Icons.arrow_downward,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.primary,
            tooltip: "Import watchers to database",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showImportDialog(context),
            evaluator: (s) {},
          ),
          WidgetsButton(
            key: Key("export-button-batch"),
            icon: Icons.arrow_upward,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.action,
            tooltip: "Export watchers from database",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showExportFileSelector(),
            evaluator: (s) {
              if (_wxController.isEmpty()) {
                s.disable();
              } else {
                s.action();
              }
            },
          ),
          WidgetsButton(
            key: Key("wipe-button-batch"),
            icon: Icons.delete_sweep,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.error,
            tooltip: "Delete all watchers",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showDeleteDialog(context),
            evaluator: (s) {
              if (_wxController.isEmpty()) {
                s.disable();
              } else {
                s.error();
              }
            },
          ),
          WidgetsButton(
            key: Key("restart-button-batch"),
            icon: Icons.refresh,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.warning,
            tooltip: "Restart all watchers",
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
            tooltip: "Add new watcher",
            evaluator: (s) => s.action(),
            onPressed: (_) {
              _showAddWatcherDialog();
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

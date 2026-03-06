import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/notify.dart';
import '../../widgets/panel.dart';
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

  void _showAddWatcherDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
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

  @override
  Widget build(BuildContext context) {
    if (!_cryptosController.hasAny() && _wxController.items.isEmpty) {
      return Column(children: [Expanded(child: _buildFetchCryptosState())]);
    }

    if (_wxController.items.isEmpty) {
      return Column(children: [Expanded(child: _buildEmptyState())]);
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Add Watcher', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            children: [
              WidgetsButton(
                icon: Icons.add,
                iconSize: 16,
                label: "Add New",
                initialState: WidgetsButtonActionState.action,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                onPressed: (_) => _showAddWatcherDialog(),
                evaluator: (s) {
                  if (!_cryptosController.hasAny()) {
                    s.disable();
                  } else {
                    s.action();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFetchCryptosState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_download_outlined, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Cryptocurrency data not available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'You need to fetch the latest crypto list before adding notification watcher.',
            style: TextStyle(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          WidgetsButton(
            icon: Icons.refresh,
            initialState: WidgetsButtonActionState.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: (s) async {
              s.progress();

              try {
                await _cryptosController.fetch();
                widgetsNotifySuccess("Cryptocurrency list successfully retrieved.");
                _cryptosController.getSymbolMap();
                s.action();
                setState(() {});
              } catch (e) {
                if (e is NetworkingException) {
                  widgetsNotifyError(e.userMessage);
                }
              } finally {
                s.reset();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAction() {
    return WidgetsPanel(
      child: Wrap(
        spacing: 4,
        children: [
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
              // sortColumnIndex: _sortColumnIndex,
              // sortAscending: _sortAscending,
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

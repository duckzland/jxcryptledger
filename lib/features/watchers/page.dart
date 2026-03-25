import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../mixins/sortable_table.dart';
import '../../widgets/action_bar.dart';
import '../../widgets/button.dart';
import '../../widgets/dialogs/alert.dart';
import '../../widgets/dialogs/show_form.dart';
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
import 'model.dart';

class WatchersPage extends StatefulWidget {
  const WatchersPage({super.key});

  @override
  State<WatchersPage> createState() => _WatchersPageState();
}

class _WatchersPageState extends State<WatchersPage> with MixinsSortableTable<WatchersPage> {
  late final WatchersController _wxController;
  final CryptosController _cryptosController = locator<CryptosController>();

  @override
  void initState() {
    super.initState();
    _wxController = locator<WatchersController>();
    _wxController.start();
    _wxController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);
    rows = _buildRows(_wxController.items);

    _registerBars("Rate Watchers");
  }

  @override
  void dispose() {
    _wxController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);

    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {
      rows = _buildRows(_wxController.items);
    });
  }

  void _removeBars() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setActions?.call(null);
    });
  }

  void _registerBars(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
      AppLayout.setActions?.call(WidgetsActionBar(leftActions: _buildDatabaseAction(), mainActions: _buildAction()));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cryptosController.isEmpty()) {
      _removeBars();
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding rate watcher.')),
        ],
      );
    }

    if (_wxController.items.isEmpty) {
      _removeBars();
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
              title: "Add Rate Watcher",
              addTitle: "Add New",
              addTooltip: "Create new rate watcher entry",
              addEvaluator: () => !_cryptosController.isEmpty(),
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

    _registerBars("Rate Watchers");
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          spacing: 12,
          children: [
            Expanded(child: _buildTable()),
            const SizedBox(height: 1),
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
    return Wrap(
      spacing: 4,
      children: [
        WidgetsDialogsAlert<WatchersModel>(
          key: Key("restart-button-batch"),
          icon: Icons.refresh,
          initialState: WidgetsButtonActionState.warning,
          tooltip: "Restart all rate watchers",
          evaluator: (s) {
            if (!_wxController.hasRestartable()) {
              s.disable();
            } else {
              s.warning();
            }
          },
          dialogTitle: "Restart Rate Watchers",
          dialogMessage:
              "This will restart all rate watchers by setting sent to 0.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Restart",
          actionStartCallback: _wxController.restart,
          actionSuccessMessage: "All watchers restarted.",
          actionErrorMessage: "Failed to restart watchers.",
        ),
        WidgetsDialogsShowForm(
          key: const Key("add-button"),
          initialState: WidgetsButtonActionState.action,
          tooltip: "Add new rate watcher",
          buildForm: _buildForm,
        ),
      ],
    );
  }

  Widget _buildDatabaseAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Wrap(
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
              suggestedPrefix: "watchers_",
              onExport: _wxController.exportDatabase,
              isEmpty: _wxController.isEmpty,
            ),
            WidgetsDialogsReset(
              key: const Key("reset-button-batch"),
              tooltip: "Delete All Rate Watcher",
              dialogTitle: "Delete All Transactions",
              dialogMessage:
                  "This will delete all rate watcher.\n"
                  "This action cannot be undone.",
              onWipe: _wxController.deleteAll,
              isEmpty: _wxController.isEmpty,
            ),
          ],
        ),
        Container(width: 1, height: 24, color: AppTheme.separator),
      ],
    );
  }

  Widget _buildTable() {
    final table = rows;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
      child: WidgetsPanel(
        child: DataTable2(
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: AppTheme.tableHeadingRowHeight,
          dataRowHeight: AppTheme.tableDataRowMinHeight,
          showCheckboxColumn: false,
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn(label: Text("From"), onSort: (col, asc) => onSort((d) => (d['_srId'] as int), col, asc)),
            DataColumn(label: Text("To"), onSort: (col, asc) => onSort((d) => (d['_rrId'] as int), col, asc)),
            DataColumn(label: Text("Ops"), onSort: (col, asc) => onSort((d) => (d['_ops'] as int), col, asc)),
            DataColumn(label: Text("Rate"), onSort: (col, asc) => onSort((d) => (d['_rate'] as double), col, asc)),
            DataColumn(label: Text("Sent"), onSort: (col, asc) => onSort((d) => (d['_sent'] as int), col, asc)),
            DataColumn(label: Text("Limit"), onSort: (col, asc) => onSort((d) => (d['_limit'] as int), col, asc)),
            DataColumn(label: Text("Duration"), onSort: (col, asc) => onSort((d) => (d['_duration'] as int), col, asc)),
            DataColumn(label: Text("Action")),
          ],
          rows: table.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r['from'])),
                DataCell(Text(r['to'])),
                DataCell(Text(r['ops'])),
                DataCell(Text(r['rate'])),
                DataCell(Text(r['sent'])),
                DataCell(Text(r['limit'])),
                DataCell(Text(r['duration'])),
                DataCell(
                  WatchersButtons(
                    tx: r['tx'],
                    wxController: _wxController,
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
    );
  }

  List<Map<String, dynamic>> _buildRows(List<WatchersModel> txs) {
    final rows = <Map<String, dynamic>>[];
    for (final tx in txs) {
      final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'from': sourceSymbol,
        'to': resultSymbol,
        'ops': tx.operatorText,
        'rate': tx.rates.toString(),
        'sent': tx.sent.toString(),
        'limit': tx.limit.toString(),
        'duration': "${tx.duration}m",
        'tx': tx,

        '_srId': tx.srId,
        '_rrId': tx.rrId,
        '_ops': tx.operator,
        '_rate': tx.rates,
        '_sent': tx.sent,
        '_limit': tx.limit,
        '_duration': tx.duration,
      });
    }
    return rows;
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../core/scrollto.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/scrollto_table.dart';
import '../../mixins/sortable_table.dart';
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
import '../../widgets/separator.dart';
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

class _WatchersPageState extends State<WatchersPage>
    with MixinsSortableTable<WatchersPage>, MixinsActionBar<WatchersPage>, MixinsScrollToTable<WatchersPage, WatchersModel> {
  final CryptosController _cryptosController = locator<CryptosController>();

  late final WatchersController _wxController;

  late List<WatchersModel> txs;

  @override
  final scrollUtil = ScrollTo();

  @override
  void initState() {
    super.initState();
    _wxController = locator<WatchersController>();
    _wxController.start();
    _wxController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);

    txs = _wxController.items;
    sorters = {
      0: (col, asc) => onSort((d) => d['_srId'] as int, col, asc),
      1: (col, asc) => onSort((d) => d['_rrId'] as int, col, asc),
      2: (col, asc) => onSort((d) => d['_ops'] as int, col, asc),
      3: (col, asc) => onSort((d) => d['_rate'] as double, col, asc),
      5: (col, asc) => onSort((d) => d['_sent'] as int, col, asc),
      6: (col, asc) => onSort((d) => d['_limit'] as int, col, asc),
      7: (col, asc) => onSort((d) => d['_duration'] as int, col, asc),
    };

    rows = _buildRows();

    registerBars("Rate Watchers");
  }

  @override
  void dispose() {
    scrollUtil.dispose();

    _wxController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);

    super.dispose();
  }

  @override
  Widget buildLeftAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Wrap(
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
        ),
        WidgetsSeparator(),
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
              onWipe: _wxController.clear,
              isEmpty: _wxController.isEmpty,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cryptosController.isEmpty()) {
      removeBars();
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding rate watcher.')),
        ],
      );
    }

    if (_wxController.items.isEmpty) {
      removeBars();
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

    registerBars("Rate Watchers");
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

  void _onControllerChanged() {
    setState(() {
      final ntx = _wxController.findNew(txs);
      txs = _wxController.items;
      rows = _buildRows();
      applySorting();
      if (ntx != null) {
        scrollToTableNewRow(ntx);
      }
    });
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

  Widget _buildTable() {
    final table = rows;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
      child: WidgetsPanel(
        child: DataTable2(
          scrollController: scrollUtil.controller,
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
            DataColumn(label: const Text("From"), onSort: sorters[0]),
            DataColumn(label: const Text("To"), onSort: sorters[1]),
            DataColumn(label: const Text("Ops"), onSort: sorters[2]),
            DataColumn(label: const Text("Rate"), onSort: sorters[3]),
            DataColumn(label: const Text("Sent"), onSort: sorters[5]),
            DataColumn(label: const Text("Limit"), onSort: sorters[6]),
            DataColumn(label: const Text("Duration"), onSort: sorters[7]),
            const DataColumn(label: Text("Action")),
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

  List<Map<String, dynamic>> _buildRows() {
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

        'uuid': tx.uuid,

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

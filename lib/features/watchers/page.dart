import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/exceptions.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../core/scrollto.dart';
import '../../core/utils.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/scrollto_table.dart';
import '../../mixins/sortable_table.dart';
import '../../mixins/state.dart';
import '../../mixins/table.dart';
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
    with
        MixinsState,
        MixinsTable,
        MixinsSortableTable<WatchersPage>,
        MixinsActionBar<WatchersPage>,
        MixinsScrollToTable<WatchersPage, WatchersModel> {
  final CryptosController _cryptosController = locator<CryptosController>();

  late final WatchersController _wxController;

  late List<WatchersModel> txs;

  @override
  String get sortableKey => "wx-group";

  @override
  final scrollToUtil = ScrollTo('wx-group-offset');

  @override
  void initState() {
    super.initState();
    _wxController = locator<WatchersController>();
    _wxController.start();
    _wxController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);

    txs = _wxController.items;
    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_srId'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_rrId'] as int, col, asc),
      2: (col, asc) => sortableOnSort((d) => d['_ops'] as int, col, asc),
      3: (col, asc) => sortableOnSort((d) => d['_rate'] as double, col, asc),
      5: (col, asc) => sortableOnSort((d) => d['_sent'] as int, col, asc),
      6: (col, asc) => sortableOnSort((d) => d['_limit'] as int, col, asc),
      7: (col, asc) => sortableOnSort((d) => d['_duration'] as int, col, asc),
    };

    rows = _buildRows();
    sortableApplySorting();

    actionbarRegister("Rate Watchers");
  }

  @override
  void dispose() {
    scrollToUtil.dispose();

    _wxController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);

    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
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
        const WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: Key("import-button-batch"),
              tooltip: "Import rate watchers to database",
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await _wxController.importDatabase(json);
                states.removeByPrefix('wx-group');
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
              tooltip: "Delete all rate watcher",
              dialogTitle: "Delete All Rate Watchers",
              dialogMessage:
                  "This will delete all rate watcher.\n"
                  "This action cannot be undone.",
              onWipe: () {
                states.removeByPrefix('wx-group');
                return _wxController.clear();
              },
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
      actionbarRemove();
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding rate watcher.')),
        ],
      );
    }

    if (_wxController.items.isEmpty) {
      actionbarRemove();
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

    actionbarRegister("Rate Watchers");
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
      sortableApplySorting();
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
          scrollController: scrollToUtil.controller,
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: AppTheme.tableHeadingRowHeight,
          dataRowHeight: AppTheme.tableDataRowMinHeight,
          showCheckboxColumn: false,
          sortColumnIndex: sortableColumnIndex,
          sortAscending: sortableAscending,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn2(label: const Text("From"), onSort: sortableSorters[0]),
            DataColumn2(label: const Text("To"), onSort: sortableSorters[1]),
            DataColumn2(label: const Text("Ops"), onSort: sortableSorters[2]),
            DataColumn2(label: const Text("Rate"), onSort: sortableSorters[3]),
            DataColumn2(label: const Text("Sent"), onSort: sortableSorters[5]),
            DataColumn2(label: const Text("Limit"), onSort: sortableSorters[6]),
            DataColumn2(label: const Text("Duration"), onSort: sortableSorters[7]),
            const DataColumn2(label: Text("Action")),
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
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rx.add({
        'from': sourceSymbol,
        'to': resultSymbol,
        'ops': tx.operatorText,
        'rate': Utils.formatSmartDouble(tx.rates),
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

    return rx;
  }
}

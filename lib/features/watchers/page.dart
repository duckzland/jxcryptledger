import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/content.dart';
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
import '../../widgets/buttons/action.dart';
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
import '../../widgets/text/selectable.dart';
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
  final CryptosController _cryptosController = CoreLocator.getit<CryptosController>();

  late final WatchersController _wxController;

  late List<WatchersModel> txs;

  @override
  String get sortableKey => "wx-group";

  @override
  String get sortableDefaultKey => "srId";

  @override
  final scrollToUtil = ScrollTo('wx-group-offset');

  @override
  void initState() {
    super.initState();
    _wxController = CoreLocator.getit<WatchersController>();
    _wxController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);

    txs = _wxController.items;
    sortableSorters = {
      "srId": (col, asc) => sortableOnSort((d) => d['tx'].srId, "srId", col, asc),
      "rrId": (col, asc) => sortableOnSort((d) => d['tx'].rrId, "rrId", col, asc),
      "ops": (col, asc) => sortableOnSort((d) => d['tx'].operatorText, "ops", col, asc),
      "rate": (col, asc) => sortableOnSort((d) => d['tx'].rates, "rate", col, asc),
      "sent": (col, asc) => sortableOnSort((d) => d['tx'].sent, "sent", col, asc),
      "limit": (col, asc) => sortableOnSort((d) => d['tx'].limit, "limit", col, asc),
      "duration": (col, asc) => sortableOnSort((d) => d['tx'].duration, "duration", col, asc),
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
      return WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding rate watcher.');
    }

    if (_wxController.items.isEmpty) {
      actionbarRemove();
      return WidgetsScreensEmpty(
        title: "Add Rate Watcher",
        addTitle: "Add New",
        addTooltip: "Create new rate watcher entry",
        addEvaluator: _cryptosController.isNotEmpty,
        importTitle: "Import",
        importTooltip: "Import rate watchers to database",
        importEvaluator: () => true,
        importCallback: (json) async => await _wxController.importDatabase(json),
        addForm: _buildForm,
      );
    }

    actionbarRegister("Rate Watchers");

    return AppContent(padding: EdgeInsets.only(left: 16, right: 16, bottom: 12), children: [_buildTable()]);
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

    return WidgetsPanel(
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
          DataColumn2(label: Text("From "), onSort: sortableSorters["srId"]),
          DataColumn2(label: Text("To "), onSort: sortableSorters["rrId"]),
          DataColumn2(label: Text("Ops "), onSort: sortableSorters["ops"]),
          DataColumn2(label: Text("Rate "), onSort: sortableSorters["rate"]),
          DataColumn2(label: Text("Sent "), onSort: sortableSorters["sent"]),
          DataColumn2(label: Text("Limit "), onSort: sortableSorters["limit"]),
          DataColumn2(label: Text("Duration "), onSort: sortableSorters["duration"]),
          DataColumn2(label: Text("Action "), fixedWidth: 110),
        ],
        rows: table.map((r) {
          final WatchersModel tx = r['tx'];
          return DataRow(
            cells: [
              DataCell(WidgetsTextSelectable(_cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin')),
              DataCell(WidgetsTextSelectable(_cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin')),
              DataCell(WidgetsTextSelectable(tx.operatorText)),
              DataCell(WidgetsTextSelectable(Utils.formatSmartDecimal(tx.rates))),
              DataCell(WidgetsTextSelectable(tx.sent.toString())),
              DataCell(WidgetsTextSelectable(tx.limit.toString())),
              DataCell(WidgetsTextSelectable("${tx.duration}m")),
              DataCell(
                WatchersButtons(
                  tx: tx,
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
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      rx.add({'tx': tx});
    }

    return rx;
  }
}

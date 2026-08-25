import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../app/content.dart';
import '../../app/exceptions.dart';
import '../../core/locator.dart';
import '../../core/scrollto.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/scrollto_table.dart';
import '../../mixins/sortable_table.dart';
import '../../mixins/state.dart';
import '../../mixins/table.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/dialogs/show_form.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/notify.dart';
import '../../widgets/panel.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../../widgets/separator.dart';
import '../../system/settings/controller.dart';
import '../../widgets/text/selectable.dart';
import '../cryptos/controller.dart';
import '../transactions/controller.dart';
import '../watchboard/panels/controller.dart';
import '../watchers/controller.dart';
import 'buttons.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

class ArchivesPage extends StatefulWidget {
  const ArchivesPage({super.key});

  @override
  State<ArchivesPage> createState() => _ArchivesPageState();
}

class _ArchivesPageState extends State<ArchivesPage>
    with
        MixinsState,
        MixinsTable,
        MixinsSortableTable<ArchivesPage>,
        MixinsActionBar<ArchivesPage>,
        MixinsScrollToTable<ArchivesPage, ArchivesModel> {
  late final ArchivesController _controller;

  final CryptosController _cryptosController = CoreLocator.getit<CryptosController>();
  final TransactionsController _txController = CoreLocator.getit<TransactionsController>();
  final PanelsController _pxController = CoreLocator.getit<PanelsController>();
  final WatchersController _wxController = CoreLocator.getit<WatchersController>();
  final SettingsController _sxController = CoreLocator.getit<SettingsController>();

  late List<ArchivesModel> txs;

  @override
  String get sortableKey => "ax-group";

  @override
  final scrollToUtil = ScrollTo('ax-group-offset');

  @override
  String get sortableDefaultKey => "timestamp";

  @override
  void initState() {
    super.initState();
    _controller = CoreLocator.getit<ArchivesController>();
    _controller.addListener(_onControllerChanged);

    _cryptosController.addListener(_onControllerChanged);

    txs = _controller.items;
    sortableSorters = {
      "timestamp": (col, asc) => sortableOnSort((d) => d['tx'].timestamp, "timestamp", col, asc),
      "type": (col, asc) => sortableOnSort((d) => d['tx'].type, "type", col, asc),
    };

    rows = _buildRows();
    sortableApplySorting();

    actionbarRegister("Data Archives");
  }

  @override
  void dispose() {
    scrollToUtil.dispose();

    _controller.removeListener(_onControllerChanged);
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
            WidgetsDialogsShowForm(
              key: const Key("add-button"),
              initialState: WidgetsButtonActionState.action,
              evaluator: (s) {
                if (_canArchive()) {
                  s.action();
                } else {
                  s.disable();
                }
              },
              tooltip: _canArchive() ? "Add new archive" : "No archivable data",
              buildForm: _buildForm,
            ),
          ],
        ),
        const WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: const Key("import-button-batch"),
              tooltip: "Import archives to database",
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await _controller.importDatabase(json);
                states.removeByPrefix('ax-group');
              },
              evaluator: (s) {},
            ),
            WidgetsDialogsExport(
              key: const Key("export-button-batch"),
              tooltip: "Export archives from database",
              suggestedPrefix: "archives_",
              onExport: _controller.exportDatabase,
              isEmpty: _controller.isEmpty,
            ),
            WidgetsDialogsReset(
              key: const Key("reset-button-batch"),
              tooltip: "Delete all archived data",
              dialogTitle: "Delete All Archives",
              dialogMessage:
                  "This will delete all archived data.\n"
                  "This action cannot be undone.",
              onWipe: () {
                states.removeByPrefix('ax-group');
                return _controller.clear();
              },
              isEmpty: _controller.isEmpty,
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
      return WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before archiving.');
    }

    if (_controller.items.isEmpty) {
      actionbarRemove();

      return WidgetsScreensEmpty(
        title: _canArchive() ? "Add Archive" : "Import Archived Data",
        addTitle: "Add New",
        addTooltip: "Create new archived entry",
        addEvaluator: _canArchive,
        addShow: _canArchive(),
        importTitle: "Import",
        importTooltip: "Import archives to database",
        importEvaluator: () => true,
        importCallback: (json) async => await _controller.importDatabase(json),
        addForm: _buildForm,
      );
    }

    actionbarRegister("Data Archives");

    return AppContent(padding: EdgeInsets.only(left: 16, right: 16, bottom: 12), children: [_buildTable()]);
  }

  Widget _buildForm(BuildContext dialogContext) {
    return Center(
      child: ArchivesForm(
        onSave: (e) async {
          if (e == null) {
            Navigator.pop(dialogContext);
            widgetsNotifySuccess("Data successfully archived");
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
    return WidgetsPanel(
      child: DataTable2(
        scrollController: scrollToUtil.controller,
        minWidth: 460,
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: tableHeadingHeight,
        dataRowHeight: tableRowHeight,
        showCheckboxColumn: false,
        sortColumnIndex: sortableColumnIndex,
        sortAscending: sortableAscending,
        isHorizontalScrollBarVisible: false,
        columns: [
          DataColumn2(label: Text("Date "), fixedWidth: 100, onSort: sortableSorters["timestamp"]),
          DataColumn2(label: Text("Data Type "), fixedWidth: 120, onSort: sortableSorters["type"]),
          DataColumn2(label: Text("Notes ")),
          DataColumn2(label: Text("Action "), fixedWidth: 80),
        ],
        rows: rows.map((r) {
          final tx = r['tx'] as ArchivesModel;
          return DataRow(
            cells: [
              DataCell(WidgetsTextSelectable(tx.timestampAsFormattedDate)),
              DataCell(WidgetsTextSelectable(tx.typeText)),
              DataCell(WidgetsTextSelectable(tx.meta['notes'] ?? "")),
              DataCell(
                ArchivesButtons(
                  tx: tx,
                  wxController: _controller,
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

  void _onControllerChanged() {
    setState(() {
      final ntx = _controller.findNew(txs);
      txs = _controller.items;
      rows = _buildRows();
      sortableApplySorting();
      if (ntx != null) {
        scrollToTableNewRow(ntx);
      }
    });
  }

  bool _canArchive() {
    return _txController.items.isNotEmpty ||
        _pxController.items.isNotEmpty ||
        _wxController.items.isNotEmpty ||
        _sxController.items.isNotEmpty;
  }
}

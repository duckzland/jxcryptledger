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
import '../../mixins/state.dart';
import '../../widgets/button.dart';
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
    with MixinsState, MixinsSortableTable<ArchivesPage>, MixinsActionBar<ArchivesPage>, MixinsScrollToTable<ArchivesPage, ArchivesModel> {
  late final ArchivesController _controller;

  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();
  final PanelsController _pxController = locator<PanelsController>();
  final WatchersController _wxController = locator<WatchersController>();

  late List<ArchivesModel> txs;

  @override
  String get sortableKey => "ax-group";

  @override
  final scrollToUtil = ScrollTo('ax-group-offset');

  @override
  void initState() {
    super.initState();
    _controller = locator<ArchivesController>();
    _controller.start();
    _controller.addListener(_onControllerChanged);

    _cryptosController.addListener(_onControllerChanged);

    txs = _controller.items;
    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_type'] as int, col, asc),
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
        WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: Key("import-button-batch"),
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
      return Column(
        children: [Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before archiving.'))],
      );
    }

    if (_controller.items.isEmpty) {
      actionbarRemove();

      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
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
            ),
          ),
        ],
      );
    }

    actionbarRegister("Data Archives");
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
      child: ArchivesForm(
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
            DataColumn2(label: const Text("Date"), fixedWidth: 100, onSort: sortableSorters[0]),
            DataColumn2(label: const Text("Data Type"), fixedWidth: 140, onSort: sortableSorters[1]),
            DataColumn2(label: const Text("Notes")),
            const DataColumn2(label: Text("Action"), fixedWidth: 80),
          ],
          rows: table.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r['date'])),
                DataCell(Text(r['type'])),
                DataCell(Text(r['notes'])),
                DataCell(
                  ArchivesButtons(
                    tx: r['tx'],
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
      ),
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      rx.add({
        'date': tx.timestampAsFormattedDate,
        'type': tx.typeText,
        'tx': tx,
        'uuid': tx.uuid,
        'notes': tx.meta['notes'] ?? "",
        "_timestamp": tx.timestamp,
        "_type": tx.type,
      });
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
    return _txController.items.isNotEmpty || _pxController.items.isNotEmpty || _wxController.items.isNotEmpty;
  }
}

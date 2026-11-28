import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/fields/accent_colors.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/table/virtualized/single.dart';
import '../../../widgets/text/selectable.dart';
import '../../../widgets/with_tooltip.dart';
import '../../cryptos/controller.dart';
import '../batch/ops.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsDialogsBatchEdit extends StatefulWidget {
  final List<TransactionsModel>? transactions;
  final void Function(Object? error)? onSave;

  const TransactionsDialogsBatchEdit({super.key, required this.onSave, this.transactions});

  @override
  State<TransactionsDialogsBatchEdit> createState() => _TransactionsDialogsBatchEditState();
}

class _TransactionsDialogsBatchEditState extends State<TransactionsDialogsBatchEdit>
    with MixinsState, MixinsTable<TransactionsDialogsBatchEdit>, MixinsSelectableTable<TransactionsDialogsBatchEdit> {
  CryptosController get _cryptoController => CoreLocator.getit<CryptosController>();
  TransactionsController get _txController => CoreLocator.getit<TransactionsController>();

  final _formKey = GlobalKey<FormState>();

  late List<TransactionsModel> txs;

  Color? _accentColor;
  String? _noteEntry;

  bool _isProcessing = false;
  bool _isExiting = false;

  Timer? _debounce;

  @override
  double get tableHeightOffset => 360;

  @override
  double get tableHeadingHeightOffset => 0;

  final ScrollController tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    txs = List.from(widget.transactions ?? []);
    txs.retainWhere((tx) => _txController.isUpdatable(tx));

    final notes = {for (final tx in txs) tx.meta['group_notes']};
    final accents = {for (final tx in txs) tx.meta['accent_color']};

    if (notes.length == 1) {
      _noteEntry = notes.first;
    }

    if (accents.length == 1) {
      _accentColor = int.tryParse(accents.first ?? '', radix: 16) != null ? Color(int.parse(accents.first, radix: 16)) : null;
    }

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }

    tableBuildColumns();
    tablePopulateData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    tableScrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> tablePopulateData() {
    tableData = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      tableData.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountTextRaw} $sourceSymbol → ${tx.rrAmountTextRaw} $resultSymbol',
        'balance': '${tx.balanceTextRaw} $resultSymbol',
        'status': tx.statusText,
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    return tableData;
  }

  List<DataColumn> tableBuildColumns() {
    if (tableColumns.isEmpty) {
      tableColumns = [
        DataColumn2(label: Text('Date '), fixedWidth: 100),
        DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
        DataColumn2(label: Text('Balance '), size: ColumnSize.M),
        DataColumn2(label: Text('Status '), fixedWidth: 140),
      ];
    }
    return tableColumns;
  }

  DataRow tableBuildRow(Map<String, dynamic> row) {
    final tx = row['tx'] as TransactionsModel;

    return DataRow(
      selected: selectableIsSelected(row['uuid']),
      onSelectChanged: (v) {
        setState(() {
          selectableSetSelected(row['uuid'], v!);
        });
      },
      cells: [
        DataCell(WidgetsWithTooltip(WidgetsTextSelectable(row['date'] ?? ''), tx.noteText, tx.meta['accent_color'])),
        DataCell(WidgetsTextSelectable(row['transaction'] ?? '')),
        DataCell(WidgetsTextSelectable(row['balance'] ?? '')),
        DataCell(Text(row['status'] ?? '')),
      ],
    );
  }

  Widget tableBuild() {
    final checkboxTheme = Theme.of(context).checkboxTheme;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: WidgetsTableVirtualizedSingle<Map<String, dynamic>>(
        controller: tableScrollController,
        data: tableData,
        rowBuilder: tableBuildRow,
        columnCount: tableColumns.length,
        childBuilder: (rows) => DataTable2(
          scrollController: tableScrollController,
          headingCheckboxTheme: checkboxTheme,
          datarowCheckboxTheme: checkboxTheme,
          showHeadingCheckBox: true,
          showCheckboxColumn: true,
          minWidth: 800,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          isHorizontalScrollBarVisible: false,
          empty: Center(
            child: Text("No transactions available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          onSelectAll: selectableOnSelectAll(() => tableData.map((r) => r['uuid'] as String)),
          columns: tableColumns,
          rows: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isExiting) {
      return const SizedBox.shrink();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1200),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (txs.isNotEmpty) const Text("Editing Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  if (txs.isNotEmpty) _buildForm(),
                  if (txs.isNotEmpty) tableBuild(),
                  if (txs.isEmpty) const Text("No transactions to edit", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0, bottom: 5),
                    child: Wrap(
                      direction: Axis.horizontal,
                      runSpacing: 20,
                      spacing: 10,
                      runAlignment: WrapAlignment.center,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WidgetsButtonsAction(
                          label: txs.isNotEmpty ? 'Cancel' : 'Close',
                          onPressed: (_) => Navigator.pop(context),
                          evaluator: (s) {
                            _isProcessing ? s.disable() : s.normal();
                          },
                        ),
                        if (txs.isNotEmpty)
                          WidgetsDialogsAlert(
                            label: "Update",
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            filledMode: true,
                            dialogTitle: "Update Confirmation",
                            dialogMessage: "This action is irreversible and will override any existing note and accents",
                            dialogCancelLabel: "Cancel",
                            dialogConfirmLabel: "Update",
                            showMessage: false,
                            initialState: WidgetsButtonActionState.action,
                            tooltip: "Update all selected transactions",
                            evaluator: (s) {
                              if (_isProcessing) {
                                s.progress();
                                return;
                              }
                              selectableHasSelectedRows() ? s.action() : s.disable();
                            },
                            actionCompleteCallback: _handleSave,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Flexible(flex: 2, child: _buildNotesPanel()),
                Flexible(flex: 2, child: _buildAccentColorsPanel()),
              ],
            );
          } else {
            return Column(spacing: 16, children: [_buildAccentColorsPanel(), _buildNotesPanel()]);
          }
        },
      ),
    );
  }

  Widget _buildAccentColorsPanel() {
    return WidgetsHeader(subtitle: "Accent Color:", subtitleFontSize: 13, spacing: 10, child: _buildColorsField());
  }

  Widget _buildNotesPanel() {
    return WidgetsHeader(subtitle: "Notes:", subtitleFontSize: 13, spacing: 10, child: _buildNotesField());
  }

  Widget _buildNotesField() {
    return WidgetsFieldsTextarea(
      title: 'Group Notes',
      helperText: 'Add notes..',
      maxLines: 3,
      initialValue: _noteEntry,
      enabled: !_isProcessing,
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildColorsField() {
    return WidgetsFieldsAccentColors(
      initialValue: _accentColor,
      enabled: !_isProcessing,
      onChange: (value) {
        setState(() => _accentColor = value);
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final sids = selectableGetSelectedRows();
    final stxs = txs.where((tx) => sids.contains(tx.uuid)).toList();
    if (stxs.isEmpty) return;

    setState(() => _isProcessing = true);

    final ops = TransactionsBatchOps();
    for (final tx in stxs) {
      final updated = tx.copyWith(
        meta: {
          ...tx.meta,
          if (_noteEntry != null) 'group_notes': _noteEntry,
          if (_accentColor != null) 'accent_color': _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0'),
        },
      );

      ops.update(updated, tag: tx);
    }

    await _txController.batchOperation(ops);

    for (final tx in ops.succeededTags<TransactionsModel>()) {
      txs.remove(tx);
      selectableSetSelected(tx.uuid, false);
    }

    if (ops.isAllSuccess) {
      txs.isNotEmpty ? widgetsNotifySuccess("Updating transactions completed successfully.") : widget.onSave?.call(null);
    } else {
      widget.onSave?.call(
        ops.toException(AppErrorCode.batchOpsFailed, 'Unable to edit the selected transactions. Please check their status and try again.'),
      );
    }

    setState(() {
      _isExiting = txs.isEmpty;
      _isProcessing = false;
      tablePopulateData();
    });
  }
}

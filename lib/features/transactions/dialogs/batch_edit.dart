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
import '../../cryptos/controller.dart';
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
    return DataRow(
      selected: selectableIsSelected(row['uuid']),
      onSelectChanged: (v) {
        setState(() {
          selectableSetSelected(row['uuid'], v!);
        });
      },
      cells: [
        DataCell(WidgetsTextSelectable(row['date'] ?? '')),
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
    return Dialog(
      insetPadding: EdgeInsets.all(24),
      constraints: BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: _isExiting
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [Text("Action editing completed")])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    if (txs.isNotEmpty) Text("Editing Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

                    if (txs.isNotEmpty) _buildForm(),
                    if (txs.isNotEmpty) tableBuild(),
                    if (txs.isEmpty) Text("No transactions to edit", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    Padding(
                      padding: EdgeInsets.only(top: 15.0, bottom: 5),
                      child: Wrap(
                        direction: Axis.horizontal,
                        runSpacing: 20,
                        spacing: 10,
                        runAlignment: WrapAlignment.center,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          WidgetsButtonsAction(
                            label: (txs.isNotEmpty) ? 'Cancel' : 'Close',
                            onPressed: (_) => Navigator.pop(context),
                            evaluator: (s) {
                              _isProcessing ? s.disable() : s.normal();
                            },
                          ),
                          if (txs.isNotEmpty)
                            WidgetsDialogsAlert(
                              label: "Update",
                              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                              filledMode: true,
                              dialogTitle: "Update Confirmation",
                              dialogMessage: "This action is irreversible and  will override any existing note and accents",
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
                                if (selectableHasSelectedRows()) {
                                  s.action();
                                } else {
                                  s.disable();
                                }
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

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));

    if (stxs.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    bool completed = true;

    List<TransactionsModel> payload = [];

    for (final tx in stxs) {
      final meta = Map<String, dynamic>.from(tx.meta);

      if (_noteEntry != null) {
        meta['group_notes'] = _noteEntry;
      }

      if (_accentColor != null) {
        meta['accent_color'] = _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0');
      }

      payload.add(tx.copyWith(meta: meta));
    }

    final txByUuid = {for (final tx in stxs) tx.uuid: tx};
    final success = await _txController.updateAll(payload);

    for (final uuid in success) {
      final tx = txByUuid[uuid];
      if (tx != null) {
        txs.remove(tx);
        selectableSetSelected(uuid, false);
      }
    }

    if (success.length < payload.length) {
      completed = false;
      final totalCount = payload.length;
      final successCount = success.length;
      final failedCount = totalCount - successCount;

      final devMessage = 'Batch edit partially or fully failed: $failedCount of $totalCount failed ($successCount succeeded).';

      final uxMessage = successCount == 0
          ? 'Unable to edit the selected transactions. Please check their status and try again.'
          : '$failedCount of $totalCount transactions could not be edited. Remaining items are still selected.';

      widget.onSave?.call(BatchException(AppErrorCode.batchOpsFailed, devMessage, uxMessage));
    }

    tablePopulateData();

    if (completed) {
      if (txs.isEmpty) {
        widget.onSave?.call(null);
        setState(() {
          _isExiting = true;
        });
      } else {
        widgetsNotifySuccess("Updating transactions completed successfully.");
      }
    }

    if (txs.isNotEmpty) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

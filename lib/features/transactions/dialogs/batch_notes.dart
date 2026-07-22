import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/runtime/locator.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/fields/accent_colors.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsDialogsBatchNotes extends StatefulWidget {
  final List<TransactionsModel>? transactions;
  final void Function(Object? error)? onSave;

  const TransactionsDialogsBatchNotes({super.key, required this.onSave, this.transactions});

  @override
  State<TransactionsDialogsBatchNotes> createState() => _TransactionsDialogsBatchNotesState();
}

class _TransactionsDialogsBatchNotesState extends State<TransactionsDialogsBatchNotes>
    with MixinsState, MixinsTable, MixinsSelectableTable {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  final _formKey = GlobalKey<FormState>();

  late List<TransactionsModel> txs;

  Color? _accentColor;
  String? _noteEntry;

  Timer? _debounce;

  @override
  double get tableHeightOffset => 290;

  @override
  double get tableHeadingHeightOffset => 0;

  @override
  void initState() {
    super.initState();

    txs = List.from(widget.transactions ?? []);
    txs.retainWhere((tx) => _txController.isUpdatable(tx));

    final notes = {for (final tx in txs) tx.meta['trading_notes']};
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
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (txs.isNotEmpty)
                const Text("Updating Transactions Notes and Accents", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

              if (txs.isNotEmpty) _buildForm(),
              if (txs.isNotEmpty) _buildTable(),
              if (txs.isEmpty) const Text("No transactions to update", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                    WidgetsButtonsAction(label: (txs.isNotEmpty) ? 'Cancel' : 'Close', onPressed: (_) => Navigator.pop(context)),
                    if (txs.isNotEmpty)
                      WidgetsDialogsAlert(
                        label: "Update",
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        filledMode: true,
                        dialogTitle: "Update Confirmation",
                        dialogMessage: "This action is irreversible and  will override any existing note and accents",
                        dialogCancelLabel: "Cancel",
                        dialogConfirmLabel: "Update",
                        showMessage: false,
                        initialState: WidgetsButtonActionState.action,
                        tooltip: "Update all selected transactions",
                        evaluator: (s) {
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

  Widget _buildTable() {
    rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountTextRaw} $sourceSymbol → ${tx.rrAmountTextRaw} $resultSymbol',
        'balance': '${tx.balanceTextRaw} $resultSymbol',
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    final checkboxTheme = Theme.of(context).checkboxTheme;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: DataTable2(
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
        columns: [
          const DataColumn2(label: Text('Date '), fixedWidth: 100),
          const DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
          const DataColumn2(label: Text('Balance '), size: ColumnSize.M),
        ],
        rows: [
          ...rows.map((r) {
            return DataRow(
              selected: selectableIsSelected(r['uuid']),
              onSelectChanged: (v) {
                setState(() {
                  selectableSetSelected(r['uuid'], v!);
                });
              },
              cells: [DataCell(Text(r['date'] ?? '')), DataCell(Text(r['transaction'] ?? '')), DataCell(Text(r['balance'] ?? ''))],
            );
          }),
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
      title: 'Trading Notes',
      helperText: 'Add notes..',
      maxLines: 3,
      initialValue: _noteEntry,
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildColorsField() {
    return WidgetsFieldsAccentColors(
      initialValue: _accentColor,
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

    for (final tx in stxs) {
      final meta = tx.meta;

      if (_noteEntry != null) {
        meta['trading_notes'] = _noteEntry;
      }

      if (_accentColor != null) {
        meta['accent_color'] = _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0');
      }

      try {
        final utx = tx.copyWith(meta: meta);
        await _txController.update(utx);
        txs.remove(tx);
        selectableSetSelected(tx.uuid, false);
      } on ValidationException catch (e) {
        widget.onSave?.call(e);
        return;
      } catch (e) {
        widget.onSave?.call(e);
        return;
      }
    }

    if (txs.isEmpty) {
      widget.onSave?.call(null);
    } else {
      widgetsNotifySuccess("Update completed successfully.");
      setState(() {});
    }
  }
}

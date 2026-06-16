import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/actionable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../dialogs/batch_action.dart';
import '../dialogs/batch_trade.dart';
import '../mixins/actions.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';
import 'buttons.dart';

class TransactionsOverviewCard extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  final BuildContext parentContext;

  final bool isOpen;

  const TransactionsOverviewCard({
    super.key,
    required this.parentContext,
    required this.id,
    required this.transactions,
    required this.onStatusChanged,
    required this.isOpen,
  });

  @override
  State<TransactionsOverviewCard> createState() => _TransactionsOverviewCardState();
}

class _TransactionsOverviewCardState extends State<TransactionsOverviewCard>
    with
        AutomaticKeepAliveClientMixin,
        MixinsActionable,
        MixinsState,
        MixinsTable,
        MixinsSelectableTable,
        MixinsSortableTable<TransactionsOverviewCard>,
        TransactionsMixinsActions {
  final TransactionCalculation _calc = TransactionCalculation();

  late final CryptosController _cryptosController;

  late String _resultSymbol;

  double _totalCapital = 0;
  double _currentHolding = 0;
  double _finalizedBalance = 0;
  double _profitLoss = 0;
  double _profitLossPercentage = 0;

  bool _isOpen = true;

  @override
  String get sortableKey => "tx-group-overview-${widget.id}";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _isOpen = widget.isOpen;

    txs = widget.transactions;
    txController = locator<TransactionsController>();

    _cryptosController = locator<CryptosController>();
    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_balanceValue'] as double, col, asc),
      2: (col, asc) => sortableOnSort((d) => d['_sourceValue'] as double, col, asc),
      3: (col, asc) => sortableOnSort((d) => d['_exchangedRateValue'] as double, col, asc),
      4: (col, asc) => sortableOnSort((d) => d['status'] as String, col, asc),
    };

    rows = _buildRows();

    sortableApplySorting();
    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    _calculateProfitLoss();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (oldWidget.isOpen != widget.isOpen) {
      setState(() {
        _isOpen = widget.isOpen;
      });
    }

    if (txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    setState(() {
      txs = widget.transactions;
      rows = _buildRows();
      sortableApplySorting();

      _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

      checkForClosable();
      checkForDeletable();
      checkForFinalizable();
      _calculateProfitLoss();
    });
  }

  void _calculateProfitLoss() {
    if (txs.isEmpty) {
      return;
    }

    final stxs = [...txs];

    if (selectableHasSelectedRows()) {
      final selectedTxIds = selectableGetSelectedRows();
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    // Extract all roots for the same srId as this group!
    double capital = 0;
    final roots = txController.collectAllRoots();
    for (final rtx in roots) {
      if (rtx.srId == widget.id) {
        capital = Math.add(capital, rtx.srAmount);
      }
    }

    final finalizedBalance = _calc.totalFinalizedBalance(stxs);
    final balance = _calc.totalActiveBalance(stxs);
    final totalBalance = Math.add(balance, finalizedBalance);
    final profitPercentage = (capital == 0) ? 0.0 : (Math.divide(Math.subtract(totalBalance, capital), capital) * 100);

    _totalCapital = capital;
    _currentHolding = balance;
    _finalizedBalance = finalizedBalance;
    _profitLoss = Math.subtract(totalBalance, capital);
    _profitLossPercentage = profitPercentage;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WidgetsPanel(child: Column(spacing: 20, children: [_buildHeader(), if (_isOpen) _buildTable()]));
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 560) {
          return Row(
            spacing: 20,
            children: [
              _buildTitle(CrossAxisAlignment.start),
              Expanded(child: _buildPanels()),
              _buildActions(),
            ],
          );
        } else {
          return Wrap(
            direction: Axis.horizontal,
            runSpacing: 14,
            spacing: 10,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildTitle(CrossAxisAlignment.start), _buildActions()]),
              _buildPanels(),
            ],
          );
        }
      },
    );
  }

  Widget _buildTitle(CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        const SizedBox(height: 5),
        Text(_cryptosController.getSymbol(widget.id) ?? 'Unknown Coin', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text('Coin ID: ${widget.id}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      direction: Axis.horizontal,
      runSpacing: 14,
      spacing: 8,
      runAlignment: WrapAlignment.center,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (isActive)
              WidgetsDialogsShowForm(
                key: const Key("trade-multiple-button"),
                icon: Icons.swap_vert,
                tooltip: "Show batch trade action for the selected transactions",
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                buildForm: (dialogContext) {
                  final stxs = [...txs];

                  if (selectableHasSelectedRows()) {
                    final selectedTxIds = selectableGetSelectedRows();
                    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
                  }

                  final atxs = stxs.where((tx) => tx.isActive || tx.isPartial).toList();

                  return TransactionsDialogsBatchTrade(
                    srId: widget.id,
                    totalAmount: _currentHolding,
                    transactions: atxs,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "Trade completed successfully.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isClosable)
              WidgetsDialogsShowForm(
                key: const Key("close-multiple-button"),
                icon: Icons.close,
                tooltip: "Close all closable transactions found in this group",
                initialState: WidgetsButtonActionState.warning,
                evaluator: (s) {
                  if (!isClosable) {
                    s.disable();
                  } else {
                    s.warning();
                  }
                },
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.close,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "Transactions closed successfully.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isFinalizable)
              WidgetsDialogsShowForm(
                key: const Key("finalize-multiple-button"),
                icon: Icons.close_fullscreen,
                tooltip: "Finalize all finalizable transactions found in this group",
                initialState: WidgetsButtonActionState.warning,
                evaluator: (s) {
                  if (!isFinalizable) {
                    s.disable();
                  } else {
                    s.warning();
                  }
                },
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.finalize,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "All transactions finalized.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isDeletable)
              WidgetsDialogsShowForm(
                key: const Key("delete-multiple-button"),
                icon: Icons.delete,
                tooltip: "Delete all transactions",
                initialState: WidgetsButtonActionState.error,
                evaluator: (s) {
                  if (!isDeletable) {
                    s.disable();
                  } else {
                    s.error();
                  }
                },
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.delete,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "All transactions deleted.",
                      error: e,
                    ),
                  );
                },
              ),

            WidgetsButton(
              key: const Key("toggle-show-button"),
              icon: _isOpen ? Icons.expand_less : Icons.expand_more,
              padding: const EdgeInsets.all(0),
              iconSize: 18,
              minimumSize: const Size(40, 40),
              tooltip: _isOpen ? "Hide table" : "Show table",
              onPressed: (_) {
                setState(() {
                  _isOpen = !_isOpen;
                  states.set("tx-group-overview-open-${widget.id}", _isOpen);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPanels() {
    return SizedBox(
      height: 38,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        child: CustomScrollView(
          scrollDirection: Axis.horizontal,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                spacing: 16,
                children: [
                  if (_totalCapital > 0)
                    _buildPanelItem(
                      title: "Total Capital",
                      subtitle: "${Utils.formatSmartDouble(_totalCapital)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_currentHolding > 0)
                    _buildPanelItem(
                      title: "Current Balance",
                      subtitle: "${Utils.formatSmartDouble(_currentHolding)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_finalizedBalance > 0)
                    _buildPanelItem(
                      title: "Finalized Balance",
                      subtitle: "${Utils.formatSmartDouble(_finalizedBalance)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_totalCapital > 0 && _profitLossPercentage != 0)
                    _buildPanelItem(
                      title: "Profit/Loss",
                      subtitle: "${Utils.formatSmartDouble(_profitLoss)} $_resultSymbol",
                      value: _profitLossPercentage,
                      comparator: 0,
                    ),
                  if (_totalCapital > 0 && _profitLossPercentage != 0)
                    _buildPanelItem(
                      title: "Profit/Loss %",
                      subtitle: "${Utils.formatSmartDouble(_profitLossPercentage, maxDecimals: 2)}%",
                      value: _profitLossPercentage,
                      comparator: 0,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelItem({required String title, required String subtitle, required double value, required double comparator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 1),
        WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 13),
      ],
    );
  }

  Widget _buildTable() {
    final canSelect = isActive && rows.length > 1;
    return SizedBox(
      width: double.infinity,
      height: tableCalculateHeight(),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        child: DataTable2(
          headingCheckboxTheme: Theme.of(context).checkboxTheme,
          datarowCheckboxTheme: Theme.of(context).checkboxTheme,
          showHeadingCheckBox: canSelect,
          showCheckboxColumn: canSelect,
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          sortColumnIndex: sortableColumnIndex,
          sortAscending: sortableAscending,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn2(label: const Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
            DataColumn2(label: const Text('Balance'), size: ColumnSize.M, onSort: sortableSorters[1]),
            DataColumn2(label: const Text('From'), size: ColumnSize.M, onSort: sortableSorters[2]),
            DataColumn2(label: const Text('Exchanged Rate'), size: ColumnSize.S, onSort: sortableSorters[3]),
            DataColumn2(label: const Text('Status'), fixedWidth: 100, onSort: sortableSorters[4]),
            const DataColumn2(label: Text('Actions'), fixedWidth: 160),
          ],
          rows: rows.map((r) {
            final tx = r['tx'] as TransactionsModel;
            final canSelect = tx.isActive || tx.isPartial;

            return DataRow(
              selected: canSelect ? selectableIsSelected(r['uuid']) : false,
              onSelectChanged: canSelect
                  ? (v) {
                      setState(() {
                        selectableSetSelected(r['uuid'], v!);
                        _calculateProfitLoss();
                        sortableApplySorting();
                      });
                    }
                  : null,
              cells: [
                DataCell(Text(r['date'])),
                DataCell(Text(r['balance'])),
                DataCell(Text(r['source'])),
                DataCell(Text(r['exchangedRate'])),
                DataCell(Text(r['status'])),
                DataCell(
                  TransactionsWidgetsButtons(
                    tx: r['tx'],
                    cryptosController: _cryptosController,
                    txController: txController,
                    onAction: () {
                      widget.onStatusChanged();
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
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);

      rx.add({
        'balance': '${tx.balanceText} $_resultSymbol',
        'source': tx.isCapital ? 'Capital' : '${tx.srAmountText} $sourceCoinSymbol to ${tx.rrAmountText} $_resultSymbol',
        'exchangedRate': tx.isCapital ? ' - ' : '${tx.rateText} $_resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,
        'uuid': tx.uuid,

        '_timestamp': tx.sanitizedTimestamp,
        '_balanceValue': tx.balance,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
      });
    }

    return rx;
  }
}

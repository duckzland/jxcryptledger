import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/actions.dart';
import '../../../mixins/sortable_table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../widgets/buttons.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsOverview extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsOverview({super.key, required this.id, required this.transactions, required this.onStatusChanged});

  @override
  State<TransactionsOverview> createState() => _TransactionsOverviewState();
}

class _TransactionsOverviewState extends State<TransactionsOverview> with MixinsActions, MixinsSortableTable<TransactionsOverview> {
  late final CryptosController _cryptosController;
  late final TransactionsController _txController;

  late String _resultSymbol;

  final TransactionCalculation _calc = TransactionCalculation();

  bool _isDeletable = false;
  bool _isClosable = false;

  double _totalCapital = 0;
  double _currentHolding = 0;
  double _profitLoss = 0;
  double _profitLossPercentage = 0;

  @override
  void initState() {
    super.initState();

    _txController = locator<TransactionsController>();

    _cryptosController = locator<CryptosController>();
    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    rows = _buildRows(widget.transactions);

    onSort((d) => d['_timestamp'] as int, sortColumnIndex, sortAscending);

    _checkForClosable();
    _checkForDeletable();
    _calculateProfitLoss();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';
      rows = _buildRows(widget.transactions);

      final col = sortColumnIndex;
      final asc = sortAscending;

      switch (col) {
        case 0:
          onSort((d) => d['_timestamp'] as int, col, asc);
          break;

        case 1:
          onSort((d) => d['_balanceValue'] as double, col, asc);
          break;

        case 2:
          onSort((d) => d['_sourceValue'] as double, col, asc);
          break;

        case 3:
          onSort((d) => d['_exchangedRateValue'] as double, col, asc);

        case 4:
          onSort((d) => d['status'] as String, col, asc);
          break;
      }

      setState(() {});
    }
  }

  void _calculateProfitLoss() {
    if (widget.transactions.isEmpty) {
      return;
    }

    // Extract all roots for the same srId as this group!
    double capital = 0;
    final roots = _txController.collectAllRoots();
    for (final rtx in roots) {
      if (rtx.srId == widget.id) {
        capital = Math.add(capital, rtx.srAmount);
      }
    }

    final balance = _calc.totalBalance(widget.transactions);
    final profitPercentage = (capital == 0) ? 0.0 : (Math.divide(Math.subtract(balance, capital), capital) * 100);

    if (mounted) {
      setState(() {
        _totalCapital = capital;
        _currentHolding = balance;
        _profitLoss = Math.subtract(balance, capital);
        _profitLossPercentage = profitPercentage;
      });
    }
  }

  void _checkForClosable() {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isRoot) continue;
      if (!tx.isActive) continue;
      try {
        final closable = _txController.isClosable(tx);
        if (closable) {
          setState(() {
            _isClosable = true;
          });
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void _checkForDeletable() {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isLeaf) continue;
      if (!tx.isActive) continue;
      try {
        final deletable = _txController.isDeletable(tx);
        if (deletable) {
          setState(() {
            _isDeletable = true;
          });
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _closeTransactions() async {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isRoot) continue;
      if (!tx.isActive) continue;
      try {
        await _txController.closeLeaf(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _deleteTransactions() async {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isLeaf) continue;
      if (!tx.isActive) continue;
      try {
        await _txController.remove(tx);
      } catch (_) {
        continue;
      }
    }
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);

      rows.add({
        'balance': '${tx.balanceText} $_resultSymbol',
        'source': '${tx.srAmountText} $sourceCoinSymbol to ${tx.rrAmountText} $_resultSymbol',
        'exchangedRate': '${tx.rateText} $_resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,

        '_timestamp': tx.sanitizedTimestamp,
        '_balanceValue': tx.balance,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
      });
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsPanel(child: Column(children: [_buildHeader(), const SizedBox(height: 20), _buildTable()]));
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
        Text('Coin ID: ${widget.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
            WidgetsDialogsAlert(
              icon: Icons.close,
              initialState: WidgetsButtonActionState.warning,
              tooltip: "Close all closable transactions found in this group",
              padding: const EdgeInsets.all(0),
              iconSize: 18,
              evaluator: (s) {
                if (!_isClosable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              dialogTitle: "Close Transactions",
              dialogMessage:
                  "Are you sure you want to close all closable transactions found in this group?\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Close",
              actionStartCallback: _closeTransactions,
              actionCompleteCallback: () => setState(() {
                _isClosable = false;
              }),
              actionSuccessMessage: "All transactions closed.",
              actionErrorMessage: "Failed to close transactions.",
            ),

            WidgetsDialogsAlert(
              icon: Icons.delete,
              initialState: WidgetsButtonActionState.error,
              tooltip: "Delete all transactions",
              padding: const EdgeInsets.all(0),
              iconSize: 18,
              evaluator: (s) {
                if (!_isDeletable) {
                  s.disable();
                } else {
                  s.error();
                }
              },
              dialogTitle: "Delete Transactions",
              dialogMessage:
                  "This will delete all transactions in this group and all of its history.\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Delete",
              actionStartCallback: _deleteTransactions,
              actionCompleteCallback: () => setState(() {
                _isDeletable = false;
              }),
              actionSuccessMessage: "All transactions deleted.",
              actionErrorMessage: "Failed to delete transactions.",
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
                  _buildPanelItem(
                    title: "Current Balance",
                    subtitle: "${Utils.formatSmartDouble(_currentHolding)} $_resultSymbol",
                    value: 0,
                    comparator: 0,
                  ),
                  if (_totalCapital > 0)
                    _buildPanelItem(
                      title: "Profit/Loss",
                      subtitle: "${Utils.formatSmartDouble(_profitLoss)} $_resultSymbol",
                      value: _profitLossPercentage,
                      comparator: 0,
                    ),
                  if (_totalCapital > 0)
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
        Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 1),
        WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 13),
      ],
    );
  }

  Widget _buildTable() {
    return SizedBox(
      width: double.infinity,
      height: (rows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
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
            DataColumn2(label: Text('Date '), fixedWidth: 100, onSort: (col, asc) => onSort((d) => d['_timestamp'] as int, col, asc)),
            DataColumn2(
              label: Text('Balance '),
              size: ColumnSize.M,
              onSort: (col, asc) => onSort((d) => d['_balanceValue'] as double, col, asc),
            ),
            DataColumn2(
              label: Text('From '),
              size: ColumnSize.M,
              onSort: (col, asc) => onSort((d) => d['_sourceValue'] as double, col, asc),
            ),
            DataColumn2(
              label: Text('Exchanged Rate '),
              size: ColumnSize.S,
              onSort: (col, asc) => onSort((d) => d['_exchangedRateValue'] as double, col, asc),
            ),
            DataColumn2(label: Text('Status '), fixedWidth: 100, onSort: (col, asc) => onSort((d) => d['status'] as String, col, asc)),
            DataColumn2(label: Text('Actions'), fixedWidth: 130),
          ],

          rows: rows.map((r) {
            return DataRow(
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
                    txController: _txController,
                    onAction: () {
                      widget.onStatusChanged();
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
}

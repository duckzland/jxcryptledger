import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../mixins/actions.dart';
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

class _TransactionsOverviewState extends State<TransactionsOverview> with MixinsActions {
  late final CryptosController _cryptosController;
  late final TransactionsController _txController;

  late List<Map<String, dynamic>> _rows;

  late String _resultSymbol;

  final TransactionCalculation _calc = TransactionCalculation();

  bool _isDeletable = false;
  bool _isClosable = false;

  int _sortColumnIndex = 0;
  bool _sortAscending = false;

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

    _rows = _buildRows(widget.transactions);

    _onSort((d) => d['_timestamp'] as int, _sortColumnIndex, _sortAscending);

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
      _rows = _buildRows(widget.transactions);

      final col = _sortColumnIndex;
      final asc = _sortAscending;

      switch (col) {
        case 0:
          _onSort((d) => d['_timestamp'] as int, col, asc);
          break;

        case 1:
          _onSort((d) => d['_balanceValue'] as double, col, asc);
          break;

        case 2:
          _onSort((d) => d['_sourceValue'] as double, col, asc);
          break;

        case 3:
          _onSort((d) => d['_exchangedRateValue'] as double, col, asc);

        case 4:
          _onSort((d) => d['status'] as String, col, asc);
          break;
      }

      setState(() {});
    }
  }

  Future<void> _calculateProfitLoss() async {
    if (widget.transactions.isEmpty) {
      return;
    }

    // Extract all roots for the same srId as this group!
    double capital = 0;
    final roots = await _txController.collectAllRoots();
    for (final rtx in roots) {
      if (rtx.srId == widget.id) {
        capital += rtx.srAmount;
      }
    }

    final balance = _calc.totalBalance(widget.transactions);
    final profitPercentage = (capital == 0) ? 0.0 : ((balance - capital) / capital) * 100;

    if (mounted) {
      setState(() {
        _totalCapital = capital;
        _currentHolding = balance;
        _profitLoss = balance - capital;
        _profitLossPercentage = profitPercentage;
      });
    }
  }

  Future<void> _checkForClosable() async {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isRoot) continue;
      if (!tx.isActive) continue;
      try {
        final closable = await _txController.isClosable(tx);
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

  Future<void> _checkForDeletable() async {
    final txs = widget.transactions;
    for (final tx in txs) {
      if (tx.isLeaf) continue;
      if (!tx.isActive) continue;
      try {
        final deletable = await _txController.isDeletable(tx);
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
        await _txController.delete(tx);
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
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text('Coin ID: ${widget.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),

        const SizedBox(width: 20),

        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

        const SizedBox(width: 10),

        WidgetsDialogsAlert(
          icon: Icons.close,
          initialState: WidgetsButtonActionState.warning,
          tooltip: "Close all closable transactions found in this group",
          padding: const EdgeInsets.all(0),
          iconSize: 18,
          evaluator: (s) async {
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
          onPressed: (dialogContext) => doAction<TransactionsModel>(
            context,
            dialogContext: dialogContext,
            onStart: _closeTransactions,
            onComplete: () => setState(() {
              _isClosable = false;
            }),
            successMessage: "All transactions closed.",
            errorMessage: "Failed to close transactions.",
          ),
        ),

        const SizedBox(width: 8),

        WidgetsDialogsAlert(
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete all transactions",
          padding: const EdgeInsets.all(0),
          iconSize: 18,
          evaluator: (s) async {
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
          onPressed: (dialogContext) => doAction<TransactionsModel>(
            context,
            dialogContext: dialogContext,
            onStart: _deleteTransactions,
            onComplete: () => setState(() {
              _isDeletable = false;
            }),
            successMessage: "All transactions deleted.",
            errorMessage: "Failed to delete transactions.",
          ),
        ),
      ],
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
    return
    // @TODO: Why this will only work on SizedBox, while the github docs specified to use Flexible or Expanded?
    SizedBox(
      width: double.infinity,
      height: (_rows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: AppTheme.tableHeadingRowHeight,
        dataRowHeight: AppTheme.tableDataRowMinHeight,
        showCheckboxColumn: false,
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        isHorizontalScrollBarVisible: false,
        columns: [
          DataColumn2(label: Text('Date '), fixedWidth: 100, onSort: (col, asc) => _onSort((d) => d['_timestamp'] as int, col, asc)),
          DataColumn2(
            label: Text('Balance '),
            size: ColumnSize.M,
            onSort: (col, asc) => _onSort((d) => d['_balanceValue'] as double, col, asc),
          ),
          DataColumn2(
            label: Text('From '),
            size: ColumnSize.M,
            onSort: (col, asc) => _onSort((d) => d['_sourceValue'] as double, col, asc),
          ),
          DataColumn2(
            label: Text('Exchanged Rate '),
            size: ColumnSize.S,
            onSort: (col, asc) => _onSort((d) => d['_exchangedRateValue'] as double, col, asc),
          ),
          DataColumn2(label: Text('Status '), fixedWidth: 100, onSort: (col, asc) => _onSort((d) => d['status'] as String, col, asc)),
          DataColumn2(label: Text('Actions'), fixedWidth: 130),
        ],

        rows: _rows.map((r) {
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
    );
  }

  void _onSort<T>(T Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    setState(() {
      _rows.sort((a, b) {
        final aField = getField(a);
        final bField = getField(b);

        if (aField is (String, num) && bField is (String, num)) {
          final c1 = aField.$1.compareTo(bField.$1);
          if (c1 != 0) return ascending ? c1 : -c1;

          final c2 = aField.$2.compareTo(bField.$2);
          return ascending ? c2 : -c2;
        }

        return ascending
            ? Comparable.compare(aField as Comparable, bField as Comparable)
            : Comparable.compare(bField as Comparable, aField as Comparable);
      });

      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }
}

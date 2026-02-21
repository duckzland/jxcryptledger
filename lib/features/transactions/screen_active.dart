import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../app/theme.dart';
import '../../core/locator.dart';
import '../cryptos/repository.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

class TransactionsActive extends StatefulWidget {
  final int srid;
  final int rrid;
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsActive({
    super.key,
    required this.srid,
    required this.rrid,
    required this.transactions,
    required this.onStatusChanged,
  });

  @override
  State<TransactionsActive> createState() => _TransactionsActiveState();
}

class _TransactionsActiveState extends State<TransactionsActive> {
  late final TransactionsController _transactionsController;
  late final CryptosRepository _cryptosRepo;

  late TextEditingController _customRateController;

  double? _customRate;

  final List<PlutoColumn> _columns = [];
  final List<PlutoRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _transactionsController = locator<TransactionsController>();
    _cryptosRepo = CryptosRepository();
    _customRateController = TextEditingController();
    _buildTableData();
  }

  @override
  void dispose() {
    _customRateController.dispose();
    super.dispose();
  }

  void _buildTableData() {
    final currentRate = _customRate ?? 0.0;

    _columns.clear();
    _rows.clear();

    // Sort transactions by timestamp descending
    final sortedTxs = List<TransactionsModel>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Build columns
    _columns.addAll([
      PlutoColumn(
        title: 'From',
        field: 'source',
        type: PlutoColumnType.text(),
        width: 120,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'To',
        field: 'balance',
        type: PlutoColumnType.text(),
        width: 100,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Exchanged Rate',
        field: 'exchangedRate',
        type: PlutoColumnType.text(),
        width: 120,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
    ]);

    // Only add these if currentRate != 0
    if (currentRate != 0) {
      _columns.addAll([
        PlutoColumn(
          title: 'Current Rate',
          field: 'currentRate',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
        PlutoColumn(
          title: 'Current Value',
          field: 'currentValue',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
        PlutoColumn(
          title: 'Profit/Loss',
          field: 'profitLoss',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
      ]);
    }

    // Always add these
    _columns.addAll([
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 80,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
      PlutoColumn(
        title: 'Date',
        field: 'date',
        type: PlutoColumnType.text(),
        width: 100,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
      PlutoColumn(
        title: 'Actions',
        field: 'actions',
        type: PlutoColumnType.text(),
        width: 120,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
      ),
    ]);

    // Build rows
    for (final tx in sortedTxs) {
      final exchangedRate = tx.srAmount > 0 ? tx.srAmount / tx.rrAmount : 0.0;
      final currentValue = tx.balance * currentRate;
      final profitLoss = currentValue - tx.balance;

      final statusText = tx.statusText;
      final dateText = tx.timestampAsDate;
      final resultCoinSymbol = _cryptosRepo.getSymbol(tx.rrId);
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId);

      final cells = {
        'source': PlutoCell(value: '${tx.srAmountText} $sourceCoinSymbol'),
        'balance': PlutoCell(value: '${tx.balanceText} $resultCoinSymbol'),
        'exchangedRate': PlutoCell(value: Utils.formatSmartDouble(exchangedRate)),
      };

      // Only include these if currentRate != 0
      if (currentRate != 0) {
        cells.addAll({
          'currentRate': PlutoCell(value: Utils.formatSmartDouble(currentRate)),
          'currentValue': PlutoCell(value: Utils.formatSmartDouble(currentValue)),
          'profitLoss': PlutoCell(value: Utils.formatSmartDouble(profitLoss)),
        });
      }

      cells.addAll({
        'status': PlutoCell(value: statusText),
        'date': PlutoCell(value: dateText),
        'actions': PlutoCell(value: tx.tid),
      });

      _rows.add(PlutoRow(cells: cells));
    }

    if (mounted) {
      setState(() {});
    }
  }

  // Calculate cumulative source value
  double _calculateCumulativeSourceValue() {
    double total = 0;
    for (final tx in widget.transactions) {
      // Calculate source_value = (balance / rrAmount) * srAmount
      if (tx.rrAmount > 0) {
        final percentageLeft = tx.balance / tx.rrAmount;
        total += percentageLeft * tx.srAmount;
      }
    }
    return total;
  }

  // Calculate average exchanged rate
  double _calculateAverageExchangedRate() {
    if (widget.transactions.isEmpty) return 0.0;
    double totalRate = 0;
    int count = 0;
    for (final tx in widget.transactions) {
      if (tx.rrAmount > 0) {
        totalRate += tx.srAmount / tx.rrAmount;
        count++;
      }
    }
    return count > 0 ? totalRate / count : 0.0;
  }

  // Calculate total balance
  double _calculateTotalBalance() {
    return widget.transactions.fold<double>(0, (sum, tx) => sum + tx.balance);
  }

  // Calculate average profit/loss
  double _calculateAverageProfitLoss() {
    if (widget.transactions.isEmpty) return 0.0;
    final currentRate = _customRate ?? 0.0;
    double totalPL = 0;
    for (final tx in widget.transactions) {
      final currentValue = tx.balance * currentRate;
      totalPL += currentValue - tx.balance;
    }
    return totalPL / widget.transactions.length;
  }

  // Calculate profit/loss percentage
  double _calculateProfitLossPercentage() {
    final avgRate = _calculateAverageExchangedRate();
    if (avgRate == 0) return 0.0;
    final avgPL = _calculateAverageProfitLoss();
    return (avgPL / avgRate) * 100;
  }

  void _showEditDialog(TransactionsModel transaction) {
    showDialog(
      context: context,
      builder: (context) => TransactionForm(
        initialData: transaction,
        onSave: (tx) async {
          await _transactionsController.add(tx);
          if (!mounted) return;
          widget.onStatusChanged();
          _buildTableData();
        },
      ),
    );
  }

  void _showTradeDialog(TransactionsModel transaction) {
    showDialog(
      context: context,
      builder: (context) => TransactionForm(
        parent: transaction,
        isTrade: true,
        onSave: (tx) async {
          await _transactionsController.add(tx);
          if (!mounted) return;
          widget.onStatusChanged();
          _buildTableData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRate = _customRate ?? 0.0;
    final cumulativeSourceValue = _calculateCumulativeSourceValue();
    final averageRate = _calculateAverageExchangedRate();
    final totalBalance = _calculateTotalBalance();
    final avgPL = _calculateAverageProfitLoss();
    final plPercentage = _calculateProfitLossPercentage();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} to ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Coin ID: ${widget.srid} - ${widget.rrid}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Total Balance: ${Utils.formatSmartDouble(cumulativeSourceValue)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} - ${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 150,
                child: TextField(
                  controller: _customRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: "Custom Rates", hintText: averageRate.toStringAsFixed(8)),
                  onChanged: (value) {
                    setState(() {
                      _customRate = double.tryParse(value);
                    });
                    _buildTableData();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Table
          SizedBox(
            height: (_rows.length * 34.0) + 40,
            child: PlutoGrid(
              columns: _columns,
              rows: _rows,
              noRowsWidget: const Center(child: Text('No transactions')),
              configuration: AppPlutoTheme.config,
              mode: PlutoGridMode.readOnly,
              onRowSecondaryTap: (event) {
                // Handle row actions
                // final txId = event.row.cells['actions']?.value as String?;
                // if (txId != null) {
                //   final tx = widget.transactions.firstWhere((t) => t.tid == txId);
                //   final hasChildren = _transactionsController.items.any((c) => c.pid == tx.tid);

                //   showMenu(
                //     context: context,
                //     position: RelativeRect.fromLTRB(event.offset.dx, event.offset.dy, 0, 0),
                //     items: [
                //       if (!hasChildren) PopupMenuItem(onTap: () => _showEditDialog(tx), child: const Text('Edit')),
                //       if (tx.balance > 0) PopupMenuItem(onTap: () => _showTradeDialog(tx), child: const Text('Trade')),
                //       if (tx.pid == '0') PopupMenuItem(onTap: () => _showCloseDialog(tx), child: const Text('Close')),
                //     ],
                //   );
                // }
              },
            ),
          ),

          const SizedBox(height: 20),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFooterItem(
                label: 'Total Balance',
                value:
                    '${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} - ${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
              ),
              _buildFooterItem(label: 'Avg Rate', value: Utils.formatSmartDouble(averageRate)),

              // ⭐ Only show these when currentRate != 0
              if (currentRate != 0) ...[
                _buildFooterItem(label: 'P/L', value: Utils.formatSmartDouble(avgPL)),
                _buildFooterItem(
                  label: 'P/L %',
                  value: '${plPercentage > 0 ? '+' : ''}${Utils.formatSmartDouble(plPercentage)}%',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showCloseDialog(TransactionsModel transaction) {
    showDialog(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('Close Transaction'),
          content: const Text('Closing this transaction will delete its history. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(dctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Close/delete not implemented')));
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

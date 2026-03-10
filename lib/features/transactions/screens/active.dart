import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/utils.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import '../../watchers/controller.dart';
import '../../watchers/form.dart';
import '../../watchers/model.dart';
import '../widgets/buttons.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsActive extends StatefulWidget {
  final int srid;
  final int rrid;

  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsActive({super.key, required this.srid, required this.rrid, required this.transactions, required this.onStatusChanged});

  @override
  State<TransactionsActive> createState() => _TransactionsActiveState();
}

class _TransactionsActiveState extends State<TransactionsActive> {
  late final CryptosController _cryptosController;
  late final RatesController _ratesController;
  late final TransactionsController _txController;
  late final WatchersController _wxController;

  late List<Map<String, dynamic>> _rows;

  late TextEditingController _customRateController;

  late String _sourceSymbol;
  late String _resultSymbol;

  bool _isReversed = false;
  bool _isDeletable = false;
  bool _isClosable = false;

  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  double? _customRate;
  double? _marketRate;

  Timer? _debounce;
  final _calc = TransactionCalculation();

  double? get effectiveMarketRate {
    final m = _marketRate;
    if (m == null) return null;

    return _isReversed ? (m == 0 ? null : 1 / m) : m;
  }

  double? get nonReversedEffectiveRate {
    final m = _marketRate;
    if (m == null) return null;

    return m;
  }

  WatchersModel? _linkedWatcher;

  @override
  void initState() {
    super.initState();

    _txController = locator<TransactionsController>();

    _cryptosController = locator<CryptosController>();
    _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
    _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

    _ratesController = locator<RatesController>();
    _ratesController.addListener(_onRatesUpdated);

    _wxController = locator<WatchersController>();
    _wxController.load();

    _wxController.addListener(_onControllerChanged);

    _loadMarketRate();

    _customRateController = TextEditingController();

    _rows = _buildRows(widget.transactions);

    _onSort((d) => d['_timestamp'] as int, _sortColumnIndex, _sortAscending);

    _checkForClosable();
    _checkForDeletable();

    _linkedWatcher = _wxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
  }

  @override
  void dispose() {
    _customRateController.dispose();
    _ratesController.removeListener(_onRatesUpdated);
    _wxController.removeListener(_onControllerChanged);

    _debounce?.cancel();

    super.dispose();
  }

  void _onRatesUpdated() {
    _loadMarketRate();
  }

  @override
  void didUpdateWidget(covariant TransactionsActive oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
      _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

      _rows = _buildRows(widget.transactions);

      final col = _sortColumnIndex;
      final asc = _sortAscending;
      final currentRate = _customRate ?? _marketRate ?? 0.0;

      switch (col) {
        case 0:
          _onSort((d) => d['_timestamp'] as int, col, asc);
          break;

        case 1:
          _onSort((d) => d['_sourceValue'] as double, col, asc);

          break;

        case 2:
          _onSort((d) => d['_balanceValue'] as double, col, asc);
          break;

        case 3:
          _onSort((d) => d['_exchangedRateValue'] as double, col, asc);

        case 4:
          if (currentRate == 0) {
            _onSort((d) => d['_status'] as String, col, asc);
          }
          break;

        case 5:
          if (currentRate != 0) {
            _onSort((d) => d['_currentValue'] as double, col, asc);
          }
          break;

        case 6:
          if (currentRate != 0) {
            _onSort((d) => d['_profitLossValue'] as double, col, asc);
          }
          break;
        case 7:
          if (currentRate != 0) {
            _onSort((d) => d['status'] as String, col, asc);
          }
          break;
      }

      setState(() {});
    }
  }

  void _onControllerChanged() {
    setState(() {});
  }

  Future<void> _loadMarketRate() async {
    final rate = await _ratesController.getStoredRate(widget.srid, widget.rrid);
    if (rate == -9999) {
      _ratesController.addQueue(widget.srid, widget.rrid);
      return;
    }
    if (mounted) {
      setState(() {
        _marketRate = rate;
        _rows = _buildRows(widget.transactions);
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

  void _showAddWatcherDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Center(
            child: WatchersForm(
              initialData: _linkedWatcher,
              initialSrId: _linkedWatcher == null ? widget.srid : null,
              initialRrId: _linkedWatcher == null ? widget.rrid : null,
              initialRate: _linkedWatcher == null ? nonReversedEffectiveRate : null,
              linkedToTx: "active-screen-${widget.srid}-${widget.rrid}",
              onSave: (e) async {
                if (e == null) {
                  Navigator.pop(dialogContext);

                  if (_linkedWatcher == null) {
                    widgetsNotifySuccess("Created notification watcher.");
                  } else {
                    widgetsNotifySuccess("Notification watcher updated");
                  }

                  setState(() {
                    _linkedWatcher = _wxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
                  });
                  return;
                }

                if (e is ValidationException) {
                  widgetsNotifyError(e.userMessage, ctx: context);
                  return;
                }

                widgetsNotifyError(e.toString(), ctx: context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete Transactions"),
            content: const Text(
              "This will delete all transactions in this group and all of its history.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Delete',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _deleteTransactions();

                    if (mounted) {
                      setState(() {
                        _isDeletable = false;
                      });
                    }

                    Navigator.pop(dialogContext);

                    widgetsNotifySuccess("All transactions deleted.");
                  } catch (e) {
                    widgetsNotifyError("Failed to delete transactions.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCloseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Close Transactions"),
            content: const Text(
              "Are you sure you want to close all closable transactions found in this group?\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Close',
                initialState: WidgetsButtonActionState.warning,
                onPressed: (_) async {
                  try {
                    await _closeTransactions();

                    if (mounted) {
                      setState(() {
                        _isClosable = false;
                      });
                    }

                    Navigator.pop(dialogContext);

                    widgetsNotifySuccess("All transactions closed.");
                  } catch (e) {
                    widgetsNotifyError("Failed to close transactions.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions;
    final averageRate = _calc.averageExchangedRate(txs, reverse: _isReversed);
    final currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    final totalSourceBalance = _calc.totalSourceBalance(txs);
    final totalBalance = _calc.totalBalance(txs);
    final avgPL = _calc.averageProfitLoss(txs, currentRate, reverse: _isReversed);
    final plPercentage = _calc.profitLossPercentage(txs, currentRate, reverse: _isReversed);

    return WidgetsPanel(
      child: Column(
        children: [
          _buildHeader(
            txs: txs,
            currentRate: currentRate,
            averageRate: averageRate,
            totalSourceBalance: totalSourceBalance,
            totalBalance: totalBalance,
            avgPL: avgPL,
            plPercentage: plPercentage,
          ),

          const SizedBox(height: 20),

          _buildTable(currentRate),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required List<TransactionsModel> txs,
    required double currentRate,
    required double averageRate,
    required double totalSourceBalance,
    required double totalBalance,
    required double avgPL,
    required double plPercentage,
  }) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text('$_sourceSymbol to $_resultSymbol Trades', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildPanels(
            averageRate: averageRate,
            totalSourceBalance: totalSourceBalance,
            totalBalance: totalBalance,
            avgPL: avgPL,
            plPercentage: plPercentage,
          ),
        ),

        const SizedBox(width: 20),

        SizedBox(
          width: 150,
          height: 42,
          child: TextField(
            controller: _customRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Custom Rates",
              hintText: averageRate.toStringAsFixed(8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            style: TextStyle(fontSize: 14),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();

              _debounce = Timer(const Duration(milliseconds: 100), () {
                setState(() {
                  _customRate = double.tryParse(value);
                  _rows = _buildRows(widget.transactions);
                });
              });
            },
          ),
        ),

        const SizedBox(width: 8),

        WidgetsButton(
          icon: Icons.swap_horiz,
          tooltip: _isReversed ? "Click to Inverse rate" : "Click to reverse rate",
          padding: const EdgeInsets.all(0),
          iconSize: 18,
          minimumSize: const Size(40, 40),
          evaluator: (s) {
            if (_isReversed) {
              s.action();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _isReversed = !_isReversed;
              _rows = _buildRows(widget.transactions);
            });
          },
        ),
        const SizedBox(width: 8),

        WidgetsButton(
          icon: Icons.add_alarm,
          padding: const EdgeInsets.all(8),
          initialState: WidgetsButtonActionState.action,
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: _linkedWatcher == null ? "Add new watcher" : "Edit watcher",
          evaluator: (s) {
            if (_linkedWatcher == null) {
              s.normal();
            } else {
              _linkedWatcher!.isSpent() ? s.error() : s.action();
            }
          },
          onPressed: (_) {
            _showAddWatcherDialog();
          },
        ),

        const SizedBox(width: 8),

        WidgetsButton(
          icon: Icons.close,
          initialState: WidgetsButtonActionState.warning,
          tooltip: "Close all closable transactions found in this group",
          padding: const EdgeInsets.all(0),
          iconSize: 18,
          minimumSize: const Size(40, 40),
          onPressed: (_) => _showCloseDialog(context),
          evaluator: (s) async {
            if (!_isClosable) {
              s.disable();
            } else {
              s.warning();
            }
          },
        ),

        const SizedBox(width: 8),

        WidgetsButton(
          icon: Icons.delete,
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete all transactions",
          padding: const EdgeInsets.all(0),
          iconSize: 18,
          minimumSize: const Size(40, 40),
          onPressed: (_) => _showDeleteDialog(context),
          evaluator: (s) async {
            if (!_isDeletable) {
              s.disable();
            } else {
              s.error();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTable(double currentRate) {
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
            size: ColumnSize.S,
            label: WidgetsHeader(title: 'From ', subtitle: _sourceSymbol),
            onSort: (col, asc) => _onSort((d) => d['_sourceValue'] as double, col, asc),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
            onSort: (col, asc) => _onSort((d) => d['_balanceValue'] as double, col, asc),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsHeader(
              title: 'Exchanged Rate ',
              subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
            ),
            onSort: (col, asc) => _onSort((d) => d['_exchangedRateValue'] as double, col, asc),
          ),

          if (currentRate != 0) ...[
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(
                title: 'Current Rate ',
                subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
              ),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'Current Value ', subtitle: _sourceSymbol),
              onSort: (col, asc) => _onSort((d) => d['_currentValue'] as double, col, asc),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'Profit/Loss ', subtitle: _sourceSymbol),
              onSort: (col, asc) => _onSort((d) => d['_profitLossValue'] as double, col, asc),
            ),
          ],

          DataColumn2(label: Text('Status '), fixedWidth: 100, onSort: (col, asc) => _onSort((d) => d['status'] as String, col, asc)),
          DataColumn2(label: Text('Actions'), fixedWidth: 130),
        ],

        rows: _rows.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['date'] ?? '0.0')),
              DataCell(Text(r['from'] ?? '0.0')),
              DataCell(Text(r['to'] ?? '0.0')),
              DataCell(Text(r['exchangedRate'] ?? '0.0')),

              if (currentRate != 0) ...[
                DataCell(WidgetsBalanceText(text: r['currentRate'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                DataCell(WidgetsBalanceText(text: r['currentValue'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                DataCell(WidgetsBalanceText(text: r['profitLoss'] ?? "-", value: r['profitLevel'], comparator: 0)),
              ],

              DataCell(Text(r['status'])),
              DataCell(
                TransactionsWidgetsButtons(
                  tx: r['tx'],
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

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      double currentValue = 0;
      double profitLoss = 0;
      double profitLevel = 0;

      if (currentRate != 0) {
        currentValue = _isReversed ? tx.balance * currentRate : tx.balance / currentRate;
        profitLoss = currentValue - tx.srAmount;

        if (profitLoss > 0) {
          profitLevel = 1;
        } else if (profitLoss < 0) {
          profitLevel = -1;
        }
      }

      rows.add({
        'from': tx.srAmountText,
        'to': tx.balanceText,
        'exchangedRate': _isReversed ? tx.rateReversedText : tx.rateText,
        'currentRate': currentRate == 0 ? null : Utils.formatSmartDouble(currentRate),
        'currentValue': currentRate == 0 ? null : Utils.formatSmartDouble(currentValue),
        'profitLoss': currentRate == 0 ? null : Utils.formatSmartDouble(profitLoss),
        'profitLevel': profitLevel,
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,

        '_timestamp': tx.sanitizedTimestamp,
        '_balanceValue': tx.rrAmount,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
        '_currentValue': currentValue,
        '_profitLossValue': profitLoss,
      });
    }

    return rows;
  }

  Widget _buildPanels({
    required double averageRate,
    required double totalSourceBalance,
    required double totalBalance,
    required double avgPL,
    required double plPercentage,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPanelItem(
          title: 'Total Balance',
          subtitle:
              '${Utils.formatSmartDouble(totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(totalBalance)} $_resultSymbol',
          value: 0,
          comparator: 0,
        ),

        _buildPanelItem(title: 'Avg Rate', subtitle: Utils.formatSmartDouble(averageRate), value: 0, comparator: 0),

        if (plPercentage != 0 && plPercentage.isFinite) ...[
          _buildPanelItem(
            title: 'Profit/Loss',
            subtitle: "${Utils.formatSmartDouble(avgPL)} $_sourceSymbol",
            value: plPercentage,
            comparator: 0,
          ),
          _buildPanelItem(
            title: 'Profit/Loss %',
            subtitle: '${Utils.formatSmartDouble(plPercentage, maxDecimals: 2)}%',
            value: plPercentage,
            comparator: 0,
          ),
        ],
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

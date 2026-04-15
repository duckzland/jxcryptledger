import 'dart:async';
import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../mixins/actions.dart';
import '../../../mixins/sortable_table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../watchboard/panels/controller.dart';
import '../../watchboard/panels/form.dart';
import '../../watchboard/panels/model.dart';
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

class _TransactionsActiveState extends State<TransactionsActive>
    with AutomaticKeepAliveClientMixin, MixinsActions, MixinsSortableTable<TransactionsActive> {
  final _calc = TransactionCalculation();

  late final CryptosController _cryptosController;
  late final RatesController _ratesController;
  late final TransactionsController _txController;
  late final WatchersController _wxController;
  late final PanelsController _pxController;

  late TextEditingController _customRateController;

  late List<TransactionsModel> txs;

  late String _sourceSymbol;
  late String _resultSymbol;

  late double _currentRate;
  late double _averageRate;
  late double _totalSourceBalance;
  late double _totalBalance;
  late double _totalPL;
  late double _totalProfit;
  late double _totalLoss;
  late double _plPercentage;

  bool _isReversed = false;
  bool _isDeletable = false;
  bool _isClosable = false;
  bool _isFinalizable = false;

  double? _customRate;
  double? _marketRate;

  Timer? _debounce;

  double? get effectiveMarketRate {
    final m = _marketRate;
    if (m == null) return null;

    return _isReversed ? (m == 0 ? null : Math.divide(1, m)) : m;
  }

  double? get nonReversedEffectiveRate {
    final c = _customRate;
    if (c != null) {
      return _isReversed ? Math.divide(1, c) : c;
    }

    final m = _marketRate;
    if (m != null) {
      return m;
    }

    return _calc.averageExchangedRate(txs, reverse: false);
  }

  WatchersModel? _linkedWatcher;
  PanelsModel? _linkedPanel;

  @override
  bool get wantKeepAlive => true;

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
    _wxController.start();
    _wxController.addListener(_onControllerChanged);

    _pxController = locator<PanelsController>();
    _pxController.start();
    _pxController.addListener(_onControllerChanged);

    txs = widget.transactions;

    _loadMarketRate();

    _customRateController = TextEditingController();

    rows = _buildRows();

    _applySorting();
    _checkForClosable();
    _checkForDeletable();
    _checkForFinalizable();
    _calculateProfitLoss();

    _linkedWatcher = _wxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
    _linkedPanel = _pxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
  }

  @override
  void dispose() {
    _customRateController.dispose();
    _ratesController.removeListener(_onRatesUpdated);
    _wxController.removeListener(_onControllerChanged);
    _pxController.removeListener(_onControllerChanged);

    _debounce?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsActive oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      setState(() {
        txs = widget.transactions;
        rows = _buildRows();
        _applySorting();

        _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
        _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

        _checkForClosable();
        _checkForDeletable();
        _checkForFinalizable();
        _calculateProfitLoss();
      });
    }
  }

  void _onRatesUpdated() {
    _loadMarketRate();
    _applySorting();
    _calculateProfitLoss();
  }

  void _calculateProfitLoss() {
    _averageRate = _calc.averageExchangedRate(txs, reverse: _isReversed);
    _currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    _totalSourceBalance = _calc.totalSourceBalance(txs);
    _totalBalance = _calc.totalBalance(txs);
    _totalPL = _calc.totalProfitLoss(txs, _currentRate, reverse: _isReversed);
    _totalProfit = _calc.totalProfit(txs, _currentRate, reverse: _isReversed);
    _totalLoss = _calc.totalLoss(txs, _currentRate, reverse: _isReversed);
    _plPercentage = _calc.profitLossPercentage(txs, _currentRate, reverse: _isReversed);
  }

  void _applySorting() {
    final col = sortColumnIndex;
    final asc = sortAscending;
    final currentRate = _customRate ?? _marketRate ?? 0.0;

    if (currentRate == 0.0 && col > 4) {
      return;
    }

    switch (col) {
      case 0:
        onSort((d) => d['_timestamp'] as int, col, asc);
        break;

      case 1:
        onSort((d) => d['_sourceValue'] as double, col, asc);

        break;

      case 2:
        onSort((d) => d['_balanceValue'] as double, col, asc);
        break;

      case 3:
        onSort((d) => d['_exchangedRateValue'] as double, col, asc);

      case 4:
        if (currentRate == 0.0) {
          onSort((d) => d['_status'] as String, col, asc);
        }
        break;

      case 5:
        if (currentRate != 0.0) {
          onSort((d) => d['_currentValue'] as double, col, asc);
        }
        break;

      case 6:
        if (currentRate != 0.0) {
          onSort((d) => d['_profitLossValue'] as double, col, asc);
        }
        break;

      case 7:
        if (currentRate != 0.0) {
          onSort((d) => d['status'] as String, col, asc);
        }
        break;
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadMarketRate() {
    final rate = _ratesController.getStoredRate(widget.srid, widget.rrid);
    if (rate == -9999) {
      _ratesController.addQueue(widget.srid, widget.rrid);
      return;
    }
    if (mounted) {
      setState(() {
        _marketRate = rate;
        rows = _buildRows();
      });
    }
  }

  void _checkForClosable() {
    _isClosable = false;

    for (final tx in txs) {
      try {
        final closable = _txController.isClosable(tx);
        if (closable) {
          _isClosable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void _checkForDeletable() {
    _isDeletable = false;

    for (final tx in txs) {
      try {
        final deletable = _txController.isDeletable(tx);
        if (deletable) {
          _isDeletable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void _checkForFinalizable() {
    _isFinalizable = false;

    for (final tx in txs) {
      try {
        final finalizable = _txController.isFinalizable(tx);
        if (finalizable) {
          _isFinalizable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _closeTransactions() async {
    for (final tx in txs) {
      try {
        await _txController.closeLeaf(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _finalizeTransactions() async {
    for (final tx in txs) {
      try {
        await _txController.finalize(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _deleteTransactions() async {
    for (final tx in txs) {
      try {
        await _txController.remove(tx);
      } catch (_) {
        continue;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WidgetsPanel(child: Column(spacing: 20, children: [_buildHeader(), _buildTable()]));
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1000) {
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
            runAlignment: WrapAlignment.center,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_buildTitle(CrossAxisAlignment.center), _buildActions(), _buildPanels()],
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
        Text('$_sourceSymbol to $_resultSymbol Trades', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildActions() {
    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = const EdgeInsets.all(0);
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
            SizedBox(
              width: 180,
              height: 40,
              child: WidgetsFieldsAmount(
                title: "Custom Rates",
                suffixText: _isReversed ? _resultSymbol : _sourceSymbol,
                helperText: _averageRate.toStringAsFixed(8),
                allowCopy: false,
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();

                  _debounce = Timer(const Duration(milliseconds: 100), () {
                    setState(() {
                      _customRate = double.tryParse(value);
                      rows = _buildRows();
                      _applySorting();
                    });
                  });
                },
              ),
            ),

            WidgetsButton(
              icon: Icons.swap_horiz,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: _isReversed ? "Click to Inverse rate" : "Click to reverse rate",
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
                  rows = _buildRows();
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            WidgetsDialogsShowForm(
              key: const Key("add-watchboard-button"),
              icon: Icons.candlestick_chart_outlined,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: _linkedPanel == null ? "Add new watchboard" : "Edit watchboard",
              persistBg: true,
              evaluator: (s) {
                if (_linkedPanel == null) {
                  s.normal();
                } else {
                  s.action();
                }
              },
              buildForm: (dialogContext) {
                return PanelsForm(
                  initialData: _linkedPanel,
                  initialSrId: _linkedPanel == null ? widget.srid : null,
                  initialRrId: _linkedPanel == null ? widget.rrid : null,
                  initialSrAmount: _linkedPanel == null ? _calc.totalSourceBalance(txs) : null,
                  linkedToTx: "active-screen-${widget.srid}-${widget.rrid}",
                  onSave: (e) => doFormSave<PanelsModel>(
                    context,
                    dialogContext: dialogContext,
                    onComplete: () => setState(() {
                      _linkedPanel = _pxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
                    }),
                    successMessage: _linkedPanel == null ? "Created watchboard entry." : "Watchboard entry updated",
                    error: e,
                  ),
                );
              },
            ),

            WidgetsDialogsShowForm(
              key: const Key("add-watcher-button"),
              icon: Icons.add_alarm,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: _linkedWatcher == null ? "Add new watcher" : "Edit watcher",
              persistBg: true,
              evaluator: (s) {
                if (_linkedWatcher == null) {
                  s.normal();
                } else {
                  _linkedWatcher!.isSpent() ? s.error() : s.action();
                }
              },
              buildForm: (dialogContext) {
                return WatchersForm(
                  initialData: _linkedWatcher,
                  initialSrId: _linkedWatcher == null ? widget.srid : null,
                  initialRrId: _linkedWatcher == null ? widget.rrid : null,
                  initialRate: _linkedWatcher == null ? nonReversedEffectiveRate : null,
                  linkedToTx: "active-screen-${widget.srid}-${widget.rrid}",
                  onSave: (e) => doFormSave<PanelsModel>(
                    context,
                    dialogContext: dialogContext,
                    onComplete: () => setState(() {
                      _linkedWatcher = _wxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
                    }),
                    successMessage: _linkedWatcher == null ? "Created rate watcher." : "Rate watcher updated",
                    error: e,
                  ),
                );
              },
            ),

            WidgetsDialogsAlert(
              icon: Icons.close,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              initialState: WidgetsButtonActionState.warning,
              tooltip: "Close all closable transactions found in this group",
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
              actionSuccessMessage: "All transactions closed.",
              actionErrorMessage: "Failed to close transactions.",
            ),

            WidgetsDialogsAlert(
              icon: Icons.close_fullscreen,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              initialState: WidgetsButtonActionState.warning,
              tooltip: "Finalize all finalizable transactions found in this group",
              evaluator: (s) {
                if (!_isFinalizable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              dialogTitle: "Finalize Transactions",
              dialogMessage:
                  "Are you sure you want to finalize all finalizable transactions found in this group?\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Finalize",
              actionStartCallback: _finalizeTransactions,
              actionSuccessMessage: "All transactions finalized.",
              actionErrorMessage: "Failed to finalize transactions.",
            ),

            WidgetsDialogsAlert(
              icon: Icons.delete,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              initialState: WidgetsButtonActionState.error,
              tooltip: "Delete all transactions",
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
              actionSuccessMessage: "All transactions deleted.",
              actionErrorMessage: "Failed to delete transactions.",
            ),
          ],
        ),
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
          sortColumnIndex: (_currentRate == 0.0 && sortColumnIndex > 4) ? null : sortColumnIndex,
          sortAscending: sortAscending,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn2(label: Text('Date '), fixedWidth: 100, onSort: (col, asc) => onSort((d) => d['_timestamp'] as int, col, asc)),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'From ', subtitle: _sourceSymbol),
              onSort: (col, asc) => onSort((d) => d['_sourceValue'] as double, col, asc),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
              onSort: (col, asc) => onSort((d) => d['_balanceValue'] as double, col, asc),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(
                title: 'Exchanged Rate ',
                subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
              ),
              onSort: (col, asc) => onSort((d) => d['_exchangedRateValue'] as double, col, asc),
            ),

            if (_currentRate != 0.0) ...[
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
                onSort: (col, asc) => onSort((d) => d['_currentValue'] as double, col, asc),
              ),
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(title: 'Profit/Loss ', subtitle: _sourceSymbol),
                onSort: (col, asc) => onSort((d) => d['_profitLossValue'] as double, col, asc),
              ),
            ],

            DataColumn2(label: Text('Status '), fixedWidth: 100, onSort: (col, asc) => onSort((d) => d['status'] as String, col, asc)),
            DataColumn2(label: Text('Actions'), fixedWidth: 160),
          ],

          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r['date'] ?? '0.0')),
                DataCell(Text(r['from'] ?? '0.0')),
                DataCell(Text(r['to'] ?? '0.0')),
                DataCell(Text(r['exchangedRate'] ?? '0.0')),

                if (_currentRate != 0) ...[
                  DataCell(WidgetsBalanceText(text: r['currentRate'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                  DataCell(WidgetsBalanceText(text: r['currentValue'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                  DataCell(WidgetsBalanceText(text: r['profitLoss'] ?? "-", value: r['profitLevel'], comparator: 0)),
                ],

                DataCell(Text(r['status'])),
                DataCell(
                  TransactionsWidgetsButtons(
                    tx: r['tx'],
                    cryptosController: _cryptosController,
                    txController: _txController,
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
    final currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      double currentValue = 0;
      double profitLoss = 0;
      double profitLevel = 0;

      if (currentRate != 0 && tx.balance != 0 && !tx.isClosed) {
        currentValue = _isReversed ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);

        if (tx.isFinalized) {
          currentValue = tx.balance;
        }

        profitLoss = Math.subtract(currentValue, tx.srAmount);

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
                  _buildPanelItem(
                    title: 'Total Balance',
                    subtitle:
                        '${Utils.formatSmartDouble(_totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(_totalBalance)} $_resultSymbol',
                    value: 0,
                    comparator: 0,
                  ),

                  _buildPanelItem(title: 'Avg Rate', subtitle: Utils.formatSmartDouble(_averageRate), value: 0, comparator: 0),

                  if (_plPercentage != 0 && _plPercentage.isFinite) ...[
                    if (_totalProfit != 0.0 && _totalLoss != 0.0)
                      _buildPanelItem(title: 'Profit', subtitle: Utils.formatSmartDouble(_totalProfit), value: _totalProfit, comparator: 0),

                    if (_totalProfit != 0.0 && _totalLoss != 0.0)
                      _buildPanelItem(title: 'Loss', subtitle: Utils.formatSmartDouble(_totalLoss), value: _totalLoss, comparator: 0),

                    _buildPanelItem(
                      title: 'Total P/L',
                      subtitle: "${Utils.formatSmartDouble(_totalPL)} $_sourceSymbol",
                      value: _plPercentage,
                      comparator: 0,
                    ),

                    _buildPanelItem(
                      title: 'P/L %',
                      subtitle: '${Utils.formatSmartDouble(_plPercentage, maxDecimals: 2)}%',
                      value: _plPercentage,
                      comparator: 0,
                    ),
                  ],
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
}

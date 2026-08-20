import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/theme.dart';
import '../../../../core/locator.dart';
import '../../../../core/math.dart';
import '../../../../core/utils.dart';
import '../../../../widgets/header.dart';
import '../../../../widgets/layouts/wrapped_two_columns.dart';
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../model.dart';
import '../../controller.dart';
import '../buttons/action.dart';

class TransactionsWidgetsCardsTree extends StatefulWidget {
  final TransactionsModel tx;
  final IndexedTreeNode<TransactionsModel> node;
  final VoidCallback onAction;
  final VoidCallback? onExit;

  final bool isTradable;
  final bool isClosable;
  final bool isDeletable;
  final bool isUpdatable;
  final bool isRefundable;
  final bool isFinalizable;

  final bool hasLeaf;
  final bool hasTradeableLeaf;

  const TransactionsWidgetsCardsTree({
    super.key,
    required this.tx,
    required this.node,
    required this.isTradable,
    required this.isClosable,
    required this.isDeletable,
    required this.isUpdatable,
    required this.isRefundable,
    required this.isFinalizable,
    required this.hasLeaf,
    required this.hasTradeableLeaf,
    required this.onAction,
    this.onExit,
  });

  @override
  State<TransactionsWidgetsCardsTree> createState() => _TransactionsWidgetsCardsTreeState();
}

class _TransactionsWidgetsCardsTreeState extends State<TransactionsWidgetsCardsTree> {
  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();
  TransactionsController get _txController => CoreLocator.getit<TransactionsController>();

  late TransactionsModel _tx;

  bool _hasLeaf = false;
  bool _leavesClosed = false;

  Decimal _capital = Decimal.zero;
  Decimal _balance = Decimal.zero;
  Decimal _finalized = Decimal.zero;
  Decimal _profit = Decimal.zero;
  Decimal _profitPercentage = Decimal.zero;
  Decimal _rBalance = Decimal.zero;
  Decimal _rFinalized = Decimal.zero;
  Decimal _rProfit = Decimal.zero;
  Decimal _rProfitPercentage = Decimal.zero;

  Color _bgColor = AppTheme.tableRowBg;
  Color _fgColor = AppTheme.text;

  Map<int, Decimal> _activeBranchAmounts = {};

  double _panelHeight = 37;

  bool get isCapital => (widget.tx.isCapital);

  @override
  void initState() {
    super.initState();

    _tx = widget.tx;

    _calculateData();
    _calculateColor();
  }

  @override
  void didUpdateWidget(covariant TransactionsWidgetsCardsTree oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    bool showBalance = _hasLeaf && _rBalance > Decimal.zero && _rBalance != widget.tx.balance;
    bool showAvailable = widget.tx.balance > Decimal.zero;
    bool showFinalized = _rFinalized != Decimal.zero;

    if (showBalance || showAvailable || showFinalized) {
      if (_calculateData(onlyUpdateIfChanged: true, tx: widget.tx)) {
        setState(() {
          _tx = widget.tx;
          _calculateColor();
        });

        return;
      }
    }

    if (_txController.isBothEqual(oldWidget.tx, widget.tx)) {
      return;
    }

    setState(() {
      _tx = widget.tx;
      _calculateData();
      _calculateColor();
    });
  }

  void _calculateColor() {
    switch (_tx.statusEnum) {
      case TransactionStatus.inactive:
        _bgColor = AppTheme.treeBgInactive;
        _fgColor = AppTheme.treeFgInactive;
        break;

      case TransactionStatus.closed:
        _bgColor = AppTheme.treeBgClosed;
        _fgColor = AppTheme.treeFgClosed;
        break;

      case TransactionStatus.finalized:
        _bgColor = AppTheme.treeBgFinalized;
        _fgColor = AppTheme.treeFgFinalized;
        break;

      default:
        _bgColor = AppTheme.treeBgNormal;
        _fgColor = AppTheme.treeFgNormal;
    }
  }

  bool _calculateData({bool onlyUpdateIfChanged = false, TransactionsModel? tx}) {
    final atx = tx ?? _tx;
    final hasLeaf = _txController.hasLeaf(atx);
    final activeBranchAmounts = _txController.collectBranchActiveAmount(atx);
    final finalizedBranchAmounts = _txController.collectBranchFinalizedAmount(atx);

    final capital = atx.srAmount;
    final balance = activeBranchAmounts[atx.srId] ?? Decimal.zero;
    final finalized = finalizedBranchAmounts[atx.srId] ?? Decimal.zero;
    final profit = Math.subtract(Math.add(balance, finalized), capital);
    final profitPercentage = (capital == Decimal.zero ? Decimal.zero : Math.multiply(Math.divide(profit, capital), Decimal.fromInt(100)));

    final rBalance = Math.add(activeBranchAmounts[atx.rrId] ?? Decimal.zero, atx.balance);
    final rFinalized = finalizedBranchAmounts[atx.rrId] ?? Decimal.zero;
    final rProfit = Math.subtract(Math.add(rBalance, rFinalized), atx.rrAmount);
    final rProfitPercentage = (atx.rrAmount == Decimal.zero
        ? Decimal.zero
        : Math.multiply(Math.divide(rProfit, atx.rrAmount), Decimal.fromInt(100)));

    final changed =
        capital != _capital ||
        balance != _balance ||
        finalized != _finalized ||
        profit != _profit ||
        profitPercentage != _profitPercentage ||
        rBalance != _rBalance ||
        rFinalized != _rFinalized ||
        rProfit != _rProfit ||
        rProfitPercentage != _rProfitPercentage;

    if (!onlyUpdateIfChanged || changed) {
      _capital = capital;
      _balance = balance;
      _finalized = finalized;
      _profit = profit;
      _profitPercentage = profitPercentage;
      _rBalance = rBalance;
      _rFinalized = rFinalized;
      _rProfit = rProfit;
      _rProfitPercentage = rProfitPercentage;
      _activeBranchAmounts = activeBranchAmounts;

      _hasLeaf = hasLeaf;
      _leavesClosed = _txController.isClosedTerminals(atx);
      if (!_hasLeaf || !atx.isActive) {
        _leavesClosed = false;
      }
    }

    return changed;
  }

  void _onAction() {
    widget.onAction();
  }

  void _onExit() async {
    widget.onExit?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 0),
      color: _bgColor,
      child: Padding(
        padding: EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 4),
        child: CustomMultiChildLayout(
          key: ValueKey(_tx.statusEnum),
          delegate: WidgetsLayoutsWrappedTwoColumns(
            onWrapChanged: (int totalRows, double currentHeight) {
              if (_panelHeight == currentHeight) return;

              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _panelHeight = currentHeight);
              });
            },

            currentHeight: _panelHeight,
          ),
          children: [
            LayoutId(id: 'left', child: _buildLeftGroup()),
            if (_activeBranchAmounts.entries.isNotEmpty) LayoutId(id: 'middle', child: _buildMiddleGroup()),
            if (!(!_hasLeaf || _balance <= Decimal.zero)) LayoutId(id: 'right', child: _buildRightGroup()),
            LayoutId(
              id: 'trailing',
              child: Padding(
                padding: EdgeInsets.only(right: _hasLeaf ? 30 : 0, top: 6, left: 8),
                child: TransactionsWidgetsButtonsAction(
                  parentContext: context,
                  key: Key("action-${_tx.uuid}"),
                  tx: _tx,
                  cryptosController: _cryptosController,
                  txController: _txController,
                  isTradable: widget.isTradable,
                  isClosable: widget.isClosable,
                  isDeletable: widget.isDeletable,
                  isUpdatable: widget.isUpdatable,
                  isRefundable: widget.isRefundable,
                  isFinalizable: widget.isFinalizable,
                  hasLeaf: widget.hasLeaf,
                  hasTradeableLeaf: widget.hasTradeableLeaf,
                  onAction: _onAction,
                  onExit: _onExit,
                  allowBalanceSnapshot: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftGroup() {
    bool showBalance = _hasLeaf && _rBalance > Decimal.zero && _rBalance != _tx.balance;
    bool showAvailable = _tx.balance > Decimal.zero;
    bool showFinalized = _rFinalized != Decimal.zero;

    Color plColor = _fgColor;
    if (_rProfitPercentage > Decimal.zero) {
      plColor = AppTheme.profit;
    } else if (_rProfitPercentage < Decimal.zero) {
      plColor = AppTheme.loss;
    }

    final srSymbol = _cryptosController.getSymbol(_tx.srId) ?? '';
    final rrSymbol = _cryptosController.getSymbol(_tx.rrId) ?? '';

    final controller = ScrollController();
    double dragStartX = 0.0;
    double scrollStartX = 0.0;

    final header = WidgetsHeader(
      titleColor: _fgColor,
      title: _tx.isCapital ? "${_tx.srAmountText} $srSymbol" : "${_tx.srAmountText} → ${_tx.rrAmountText}",
      subtitle: _tx.isCapital ? "${_tx.timestampAsFormattedDate} | Capital" : "${_tx.timestampAsFormattedDate} | $srSymbol - $rrSymbol",
      reversed: true,
      selectable: true,
    );

    return Listener(
      onPointerDown: (event) {
        dragStartX = event.position.dx;
        scrollStartX = controller.offset;
      },
      onPointerMove: (event) {
        final delta = dragStartX - event.position.dx;
        final newOffset = (scrollStartX + delta).clamp(0.0, controller.position.maxScrollExtent);
        controller.jumpTo(newOffset);
      },
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        child: Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            WidgetsWithTooltip(header, _tx.noteText, _tx.meta['accent_color']),

            WidgetsHeader(titleColor: _fgColor, title: _tx.statusText, subtitle: "Status", reversed: true),

            if (showAvailable)
              WidgetsHeader(titleColor: _fgColor, title: _tx.balanceText, subtitle: "Avail. $rrSymbol", reversed: true, selectable: true),

            if (showBalance)
              WidgetsHeader(
                titleColor: _fgColor,
                title: Utils.formatSmartDecimal(_rBalance),
                subtitle: "Bal. $rrSymbol",
                reversed: true,
                selectable: true,
              ),

            if (showFinalized)
              WidgetsHeader(
                titleColor: _fgColor,
                title: Utils.formatSmartDecimal(_rFinalized),
                subtitle: "Fin. $rrSymbol",
                reversed: true,
                selectable: true,
              ),

            if (showBalance || _leavesClosed)
              WidgetsHeader(
                titleColor: plColor,
                title:
                    "${_rProfit >= Decimal.zero ? '+' : ''}${Utils.formatSmartDecimal(_rProfit)}"
                    "(${_rProfit >= Decimal.zero ? '+' : ''}${Utils.formatSmartDecimal(_rProfitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
                subtitle: "P/L $rrSymbol (%)",
                reversed: true,
                selectable: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightGroup() {
    if (!_hasLeaf || _balance <= Decimal.zero || isCapital) return const SizedBox.shrink();

    Color plColor = _fgColor;
    if (_profitPercentage > Decimal.zero) {
      plColor = AppTheme.profit;
    } else if (_profitPercentage < Decimal.zero) {
      plColor = AppTheme.loss;
    }

    final srSymbol = _cryptosController.getSymbol(_tx.srId) ?? '';

    final controller = ScrollController();
    double dragStartX = 0.0;
    double scrollStartX = 0.0;

    return Listener(
      onPointerDown: (event) {
        dragStartX = event.position.dx;
        scrollStartX = controller.offset;
      },
      onPointerMove: (event) {
        final delta = dragStartX - event.position.dx;
        final newOffset = (scrollStartX + delta).clamp(0.0, controller.position.maxScrollExtent);
        controller.jumpTo(newOffset);
      },
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 15,
          children: [
            WidgetsHeader(
              titleColor: _fgColor,
              title: Utils.formatSmartDecimal(_capital),
              subtitle: "Cap. $srSymbol",
              reversed: true,
              selectable: true,
            ),
            if (_balance > Decimal.zero)
              WidgetsHeader(
                titleColor: _fgColor,
                title: Utils.formatSmartDecimal(_balance),
                subtitle: "Bal. $srSymbol",
                reversed: true,
                selectable: true,
              ),
            if (_finalized > Decimal.zero)
              WidgetsHeader(
                titleColor: _fgColor,
                title: Utils.formatSmartDecimal(_finalized),
                subtitle: "Fin. $srSymbol",
                reversed: true,
                selectable: true,
              ),
            WidgetsHeader(
              titleColor: plColor,
              title:
                  "${_profit >= Decimal.zero ? '+' : ''}${Utils.formatSmartDecimal(_profit)}"
                  "(${_profit >= Decimal.zero ? '+' : ''}${Utils.formatSmartDecimal(_profitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
              subtitle: "P/L $srSymbol (%)",
              reversed: true,
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleGroup() {
    final controller = ScrollController();
    double dragStartX = 0.0;
    double scrollStartX = 0.0;

    return Listener(
      onPointerDown: (event) {
        dragStartX = event.position.dx;
        scrollStartX = controller.offset;
      },
      onPointerMove: (event) {
        final delta = dragStartX - event.position.dx;
        controller.jumpTo((scrollStartX + delta).clamp(0.0, controller.position.maxScrollExtent));
      },
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: NeverScrollableScrollPhysics(),
        child: Row(
          spacing: 25,
          mainAxisSize: MainAxisSize.min,
          children: _activeBranchAmounts.entries.map((entry) {
            final symbol = _cryptosController.getSymbol(entry.key) ?? '';
            final amount = Utils.formatSmartDecimal(entry.value);

            return WidgetsHeader(titleColor: _fgColor, title: amount, subtitle: "Bal. $symbol", reversed: true, selectable: true);
          }).toList(),
        ),
      ),
    );
  }
}

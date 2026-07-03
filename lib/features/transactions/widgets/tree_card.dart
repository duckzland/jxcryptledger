import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../widgets/header.dart';
import '../../../widgets/layouts/wrapped_two_columns.dart';
import '../../../widgets/with_tooltip.dart';
import '../../cryptos/controller.dart';
import '../model.dart';
import '../controller.dart';
import 'buttons.dart';

class TransactionsTreeCard extends StatefulWidget {
  final TransactionsModel tx;
  final IndexedTreeNode<TransactionsModel> node;
  final VoidCallback onAction;

  const TransactionsTreeCard({super.key, required this.tx, required this.node, required this.onAction});

  @override
  State<TransactionsTreeCard> createState() => _TransactionsTreeCardState();
}

class _TransactionsTreeCardState extends State<TransactionsTreeCard> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  CryptosController get _cryptosController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  late TransactionsModel _tx;

  bool _hasLeaf = false;
  bool _leavesClosed = false;

  double _capital = 0;
  double _balance = 0;
  double _finalized = 0;
  double _profit = 0;
  double _profitPercentage = 0;
  double _rBalance = 0;
  double _rFinalized = 0;
  double _rProfit = 0;
  double _rProfitPercentage = 0;

  Color _bgColor = AppTheme.rowHeaderBg;
  Color _fgColor = AppTheme.text;

  Map<int, double> _activeBranchAmounts = {};

  double _panelHeight = 40;

  late AnimationController _controller;
  late Animation<double> _fade;

  bool get isCapital => (widget.tx.isCapital);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _tx = widget.tx;

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1.0);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _calculateData();
    _calculateColor();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsTreeCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    bool showBalance = _hasLeaf && _rBalance > 0 && _rBalance != widget.tx.balance;
    bool showAvailable = widget.tx.balance > 0;
    bool showFinalized = _rFinalized != 0;

    if (showBalance || showAvailable || showFinalized) {
      if (_calculateData(onlyUpdateIfChanged: true, tx: widget.tx)) {
        setState(() {
          _tx = widget.tx;
          _calculateColor();
        });
      }
      return;
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
        _bgColor = AppTheme.mutedBg;
        _fgColor = AppTheme.textMuted;
        break;

      case TransactionStatus.closed:
        _bgColor = AppTheme.closedBg;
        _fgColor = AppTheme.textMuted;
        break;

      case TransactionStatus.finalized:
        _bgColor = AppTheme.finalizedBg;
        _fgColor = AppTheme.textMuted;
        break;

      default:
        _bgColor = AppTheme.rowHeaderBg;
        _fgColor = AppTheme.text;
    }
  }

  bool _calculateData({bool onlyUpdateIfChanged = false, TransactionsModel? tx}) {
    final atx = tx ?? _tx;
    final hasLeaf = _txController.hasLeaf(atx);
    final activeBranchAmounts = _txController.collectBranchActiveAmount(atx);
    final finalizedBranchAmounts = _txController.collectBranchFinalizedAmount(atx);

    final capital = atx.srAmount;
    final balance = activeBranchAmounts[atx.srId] ?? 0;
    final finalized = finalizedBranchAmounts[atx.srId] ?? 0;
    final profit = Math.subtract(Math.add(balance, finalized), capital);
    final profitPercentage = (capital == 0 ? 0 : Math.multiply(Math.divide(profit, capital), 100)) as double;

    final rBalance = Math.add(activeBranchAmounts[atx.rrId] ?? 0, atx.balance);
    final rFinalized = finalizedBranchAmounts[atx.rrId] ?? 0;
    final rProfit = Math.subtract(Math.add(rBalance, rFinalized), atx.rrAmount);
    final rProfitPercentage = (atx.rrAmount == 0 ? 0 : Math.multiply(Math.divide(rProfit, atx.rrAmount), 100)) as double;

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
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FadeTransition(
      opacity: _fade,
      child: Card(
        margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
        color: _bgColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              if (!(!_hasLeaf || _balance <= 0)) LayoutId(id: 'right', child: _buildRightGroup()),
              LayoutId(
                id: 'trailing',
                child: Padding(
                  padding: const EdgeInsets.only(right: 25, top: 6, left: 8),
                  child: TransactionsWidgetsButtons(
                    key: Key("action-${_tx.uuid}"),
                    tx: _tx,
                    cryptosController: _cryptosController,
                    txController: _txController,
                    onAction: _onAction,
                    onExit: _onExit,
                    allowBalanceSnapshot: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftGroup() {
    bool showBalance = _hasLeaf && _rBalance > 0 && _rBalance != _tx.balance;
    bool showAvailable = _tx.balance > 0;
    bool showFinalized = _rFinalized != 0;

    Color plColor = _fgColor;
    if (_rProfitPercentage > 0) {
      plColor = AppTheme.profit;
    } else if (_rProfitPercentage < 0) {
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
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            WidgetsWithTooltip(header, _tx.noteText),

            WidgetsHeader(titleColor: _fgColor, title: _tx.statusText, subtitle: "Status", reversed: true),

            if (showAvailable) WidgetsHeader(titleColor: _fgColor, title: _tx.balanceText, subtitle: "Avail. $rrSymbol", reversed: true),

            if (showBalance)
              WidgetsHeader(titleColor: _fgColor, title: Utils.formatSmartDouble(_rBalance), subtitle: "Bal. $rrSymbol", reversed: true),

            if (showFinalized)
              WidgetsHeader(titleColor: _fgColor, title: Utils.formatSmartDouble(_rFinalized), subtitle: "Fin. $rrSymbol", reversed: true),

            if (showBalance || _leavesClosed)
              WidgetsHeader(
                titleColor: plColor,
                title:
                    "${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfit)}"
                    "(${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
                subtitle: "P/L $rrSymbol (%)",
                reversed: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightGroup() {
    if (!_hasLeaf || _balance <= 0 || isCapital) return const SizedBox.shrink();

    Color plColor = _fgColor;
    if (_profitPercentage > 0) {
      plColor = AppTheme.profit;
    } else if (_profitPercentage < 0) {
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
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 15,
          children: [
            WidgetsHeader(titleColor: _fgColor, title: Utils.formatSmartDouble(_capital), subtitle: "Cap. $srSymbol", reversed: true),
            if (_balance > 0)
              WidgetsHeader(titleColor: _fgColor, title: Utils.formatSmartDouble(_balance), subtitle: "Bal. $srSymbol", reversed: true),
            if (_finalized > 0)
              WidgetsHeader(titleColor: _fgColor, title: Utils.formatSmartDouble(_finalized), subtitle: "Fin. $srSymbol", reversed: true),
            WidgetsHeader(
              titleColor: plColor,
              title:
                  "${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profit)}"
                  "(${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
              subtitle: "P/L $srSymbol (%)",
              reversed: true,
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
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          spacing: 25,
          mainAxisSize: MainAxisSize.min,
          children: _activeBranchAmounts.entries.map((entry) {
            final symbol = _cryptosController.getSymbol(entry.key) ?? '';
            final amount = Utils.formatSmartDouble(entry.value);

            return WidgetsHeader(titleColor: _fgColor, title: amount, subtitle: "Bal. $symbol", reversed: true);
          }).toList(),
        ),
      ),
    );
  }
}

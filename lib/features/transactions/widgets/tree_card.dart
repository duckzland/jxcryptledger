import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../widgets/header.dart';
import '../../../widgets/layouts/wrapped_two_columns.dart';
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
  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();

  late TransactionsModel _tx;

  bool _hasLeaf = false;
  bool _leavesClosed = false;

  double _capital = 0;
  double _balance = 0;
  double _profit = 0;
  double _profitPercentage = 0;
  double _rBalance = 0;
  double _rProfit = 0;
  double _rProfitPercentage = 0;

  Color _bgColor = AppTheme.rowHeaderBg;
  Color _fgColor = AppTheme.text;

  Map<int, double> _branchAmounts = {};

  double _panelHeight = 40;

  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _tx = widget.tx;

    _txController.addListener(_onControllerChange);

    if (_tx.statusEnum == TransactionStatus.inactive) {
      _bgColor = AppTheme.mutedBg;
      _fgColor = AppTheme.textMuted;
    }
    if (_tx.statusEnum == TransactionStatus.closed) {
      _bgColor = AppTheme.closedBg;
      _fgColor = AppTheme.textMuted;
    }

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1.0);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _calculateData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _txController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final ntx = _txController.get(_tx.tid);
    if (ntx == null) {
      return;
    }

    setState(() {
      _tx = ntx;
      _calculateData();
      if (_tx.statusEnum == TransactionStatus.inactive) {
        _bgColor = AppTheme.mutedBg;
        _fgColor = AppTheme.textMuted;
      } else if (_tx.statusEnum == TransactionStatus.closed) {
        _bgColor = AppTheme.closedBg;
        _fgColor = AppTheme.textMuted;
      } else {
        _bgColor = AppTheme.rowHeaderBg;
        _fgColor = AppTheme.text;
      }
    });
  }

  void _calculateData() {
    _hasLeaf = _txController.hasLeaf(_tx);
    _branchAmounts = _txController.collectBranchActiveAmount(_tx);

    _capital = _tx.srAmount;
    _balance = _branchAmounts[_tx.srId] ?? 0;
    _profit = Math.subtract(_balance, _capital);
    _profitPercentage = (_capital == 0 ? 0 : (Math.divide(_profit, _capital) * 100)) as double;

    _rBalance = Math.add(_branchAmounts[_tx.rrId] ?? 0, _tx.balance);
    _rProfit = Math.subtract(_rBalance, _tx.rrAmount);
    _rProfitPercentage = (_tx.rrAmount == 0 ? 0 : (Math.divide(_rProfit, _tx.rrAmount) * 100)) as double;

    _leavesClosed = _txController.isClosedTerminals(_tx);
    if (!_hasLeaf || !_tx.isActive) {
      _leavesClosed = false;
    }
  }

  void _onAction() {
    _onControllerChange();
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
              if (_branchAmounts.entries.isNotEmpty) LayoutId(id: 'middle', child: _buildMiddleGroup()),
              if (!(!_hasLeaf || _balance <= 0)) LayoutId(id: 'right', child: _buildRightGroup()),
              LayoutId(
                id: 'trailing',
                child: Padding(
                  padding: EdgeInsets.only(right: 25, top: 6, left: 8),
                  child: TransactionsWidgetsButtons(
                    tx: _tx,
                    cryptosController: _cryptosController,
                    txController: _txController,
                    onAction: _onAction,
                    onExit: _onExit,
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
            WidgetsHeader(
              titleColor: _fgColor,
              title: "${_tx.srAmountText} $srSymbol → ${_tx.rrAmountText} $rrSymbol",
              subtitle: _tx.timestampAsFormattedDate,
              reversed: true,
            ),

            WidgetsHeader(titleColor: _fgColor, title: _tx.statusText, subtitle: "Status", reversed: true),

            if (showAvailable)
              WidgetsHeader(titleColor: _fgColor, title: "${_tx.balanceText} $rrSymbol", subtitle: "Available", reversed: true),

            if (showBalance)
              WidgetsHeader(
                titleColor: _fgColor,
                title: "${Utils.formatSmartDouble(_rBalance)} $rrSymbol",
                subtitle: "Balance",
                reversed: true,
              ),

            if (showBalance || _leavesClosed)
              WidgetsHeader(
                titleColor: plColor,
                title:
                    "${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfit)} $rrSymbol "
                    "(${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
                subtitle: "Return (%)",
                reversed: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightGroup() {
    if (!_hasLeaf || _balance <= 0) return const SizedBox.shrink();

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
            WidgetsHeader(
              titleColor: _fgColor,
              title: "${Utils.formatSmartDouble(_capital)} $srSymbol",
              subtitle: "Capital",
              reversed: true,
            ),
            WidgetsHeader(
              titleColor: _fgColor,
              title: "${Utils.formatSmartDouble(_balance)} $srSymbol",
              subtitle: "Balance",
              reversed: true,
            ),
            WidgetsHeader(
              titleColor: plColor,
              title:
                  "${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profit)} $srSymbol "
                  "(${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profitPercentage, maxDecimals: 2, smartDecimal: false)}%)",
              subtitle: "Return (%)",
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
          children: _branchAmounts.entries.map((entry) {
            final symbol = _cryptosController.getSymbol(entry.key) ?? '';
            final amount = Utils.formatSmartDouble(entry.value);

            return WidgetsHeader(titleColor: _fgColor, title: amount, subtitle: symbol, reversed: true);
          }).toList(),
        ),
      ),
    );
  }
}

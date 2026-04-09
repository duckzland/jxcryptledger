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
  final TreeNode<TransactionsModel> node;
  final VoidCallback onAction;

  const TransactionsTreeCard({super.key, required this.tx, required this.node, required this.onAction});

  @override
  State<TransactionsTreeCard> createState() => _TransactionsTreeCardState();
}

class _TransactionsTreeCardState extends State<TransactionsTreeCard> with AutomaticKeepAliveClientMixin {
  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();

  bool _hasLeaf = false;

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

  late TransactionsModel tx = widget.tx;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _txController.addListener(onControllerChange);

    if (tx.statusEnum == TransactionStatus.inactive) {
      _bgColor = AppTheme.mutedBg;
      _fgColor = AppTheme.textMuted;
    }
    if (tx.statusEnum == TransactionStatus.closed) {
      _bgColor = AppTheme.closedBg;
      _fgColor = AppTheme.textMuted;
    }
    _loadData();
  }

  @override
  void dispose() {
    _txController.removeListener(onControllerChange);
    super.dispose();
  }

  void onControllerChange() {
    final ntx = _txController.get(widget.tx.tid);
    if (ntx == null || ntx == tx) {
      return;
    }

    tx = ntx;
    if (tx.statusEnum == TransactionStatus.inactive) {
      _bgColor = AppTheme.mutedBg;
      _fgColor = AppTheme.textMuted;
    } else if (tx.statusEnum == TransactionStatus.closed) {
      _bgColor = AppTheme.closedBg;
      _fgColor = AppTheme.textMuted;
    } else {
      _bgColor = AppTheme.rowHeaderBg;
      _fgColor = AppTheme.text;
    }

    setState(() {
      _bgColor = _bgColor;
      _fgColor = _fgColor;
      tx = tx;
    });
  }

  Future<void> _loadData() async {
    final leaf = _txController.hasLeaf(tx);
    final branch = _txController.collectBranchActiveAmount(tx);
    final totalResult = branch[tx.srId] ?? 0;
    final totalReturnResult = branch[tx.rrId] ?? 0;

    final cap = tx.srAmount;
    final bal = totalResult;
    final prof = Math.subtract(bal, cap);
    final profPct = cap == 0 ? 0 : (Math.divide(prof, cap) * 100);

    final rCap = tx.rrAmount;
    final rBal = totalReturnResult;
    final rProf = Math.subtract(rBal, rCap);
    final rProfPct = rCap == 0 ? 0 : (Math.divide(rProf, rCap) * 100);

    setState(() {
      _hasLeaf = leaf;
      _capital = cap;
      _balance = bal;
      _profit = prof;
      _profitPercentage = profPct as double;
      _rBalance = rBal;
      _rProfit = rProf;
      _rProfitPercentage = rProfPct as double;
      _branchAmounts = branch;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
      color: _bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CustomMultiChildLayout(
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
                  tx: widget.tx,
                  cryptosController: _cryptosController,
                  txController: _txController,
                  onAction: widget.onAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftGroup() {
    bool showBalance = _hasLeaf && _rBalance > 0;

    Color plColor = _fgColor;
    if (_rProfitPercentage > 0) {
      plColor = const Color.fromARGB(255, 112, 225, 104);
    } else if (_rProfitPercentage < 0) {
      plColor = const Color.fromARGB(255, 255, 109, 109);
    }

    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? '';
    final rrSymbol = _cryptosController.getSymbol(tx.rrId) ?? '';

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
              title: "${tx.srAmountText} $srSymbol → ${tx.rrAmountText} $rrSymbol",
              subtitle: tx.timestampAsFormattedDate,
              reversed: true,
            ),
            WidgetsHeader(titleColor: _fgColor, title: tx.statusText, subtitle: "Status", reversed: true),
            WidgetsHeader(titleColor: _fgColor, title: "${tx.balanceText} $rrSymbol", subtitle: "Available", reversed: true),
            if (showBalance)
              WidgetsHeader(
                titleColor: _fgColor,
                title: "${Utils.formatSmartDouble(_rBalance)} $rrSymbol",
                subtitle: "Balance",
                reversed: true,
              ),
            if (showBalance)
              WidgetsHeader(
                titleColor: plColor,
                title:
                    "${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfit)} $srSymbol "
                    "(${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfitPercentage, maxDecimals: 2)}%)",
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
      plColor = const Color.fromARGB(255, 112, 225, 104);
    } else if (_profitPercentage < 0) {
      plColor = const Color.fromARGB(255, 255, 109, 109);
    }

    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? '';

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
                  "(${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profitPercentage, maxDecimals: 2)}%)",
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

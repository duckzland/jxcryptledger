import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
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

class _TransactionsTreeCardState extends State<TransactionsTreeCard> {
  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();

  final _leftKey = GlobalKey();
  final _rightKey = GlobalKey();
  final _middleKey = GlobalKey();
  final _trailingKey = GlobalKey();

  double _leftWidth = 0;
  double _rightWidth = 0;
  double _middleWidth = 0;
  double _trailingWidth = 0;

  bool _loading = true;
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

  @override
  void initState() {
    super.initState();

    final tx = widget.tx;
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

  Future<void> _loadData() async {
    final tx = widget.tx;

    final results = await Future.wait([_txController.hasLeaf(tx), _txController.collectBranchActiveAmount(tx)]);

    final leaf = results[0] as bool;
    final branch = results[1] as Map<int, double>;
    final totalResult = branch[tx.srId] ?? 0;
    final totalReturnResult = branch[tx.rrId] ?? 0;

    final cap = tx.srAmount;
    final bal = totalResult;
    final prof = bal - cap;
    final profPct = cap == 0 ? 0 : (prof / cap) * 100;

    final rCap = tx.rrAmount;
    final rBal = totalReturnResult;
    final rProf = rBal - rCap;
    final rProfPct = rCap == 0 ? 0 : (rProf / rCap) * 100;

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
      _loading = false;
    });
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lw = _leftKey.currentContext?.size?.width ?? 0;
      final rw = _rightKey.currentContext?.size?.width ?? 0;
      final mw = _middleKey.currentContext?.size?.width ?? 0;
      final tw = _trailingKey.currentContext?.size?.width ?? 0;

      if (tw != _trailingWidth) {
        setState(() => _trailingWidth = tw);
      }

      if (lw != _leftWidth || rw != _rightWidth || mw != _middleWidth) {
        setState(() {
          _leftWidth = lw;
          _rightWidth = rw;
          _middleWidth = mw;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
      color: _bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CustomMultiChildLayout(
          delegate: WidgetsLayoutsWrappedTwoColumns(
            onWrapChanged: (wrap) {
              final double target = wrap ? 95 : 40;

              if (_panelHeight == target) return;

              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _panelHeight = target);
              });
            },

            currentHeight: _panelHeight,
          ),
          children: [
            LayoutId(id: 'left', child: _buildLeftGroup()),
            LayoutId(id: 'middle', child: _buildMiddleGroup()),
            LayoutId(id: 'right', child: _buildRightGroup()),
            LayoutId(
              id: 'trailing',
              child: Padding(
                padding: EdgeInsets.only(left: 10, right: 25, top: 6),
                child: TransactionsButtons(tx: widget.tx, onAction: widget.onAction),
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

    final tx = widget.tx;
    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? '';
    final rrSymbol = _cryptosController.getSymbol(tx.rrId) ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetsHeader(
          titleColor: _fgColor,
          title: "${tx.srAmountText} $srSymbol → ${tx.rrAmountText} $rrSymbol",
          subtitle: tx.timestampAsFormattedDate,
          reversed: true,
        ),
        const SizedBox(width: 20),
        WidgetsHeader(titleColor: _fgColor, title: tx.statusText, subtitle: "Status", reversed: true),
        const SizedBox(width: 20),
        WidgetsHeader(titleColor: _fgColor, title: "${tx.balanceText} $rrSymbol", subtitle: "Available", reversed: true),
        if (showBalance) const SizedBox(width: 20),
        if (showBalance)
          WidgetsHeader(
            titleColor: _fgColor,
            title: "${Utils.formatSmartDouble(_rBalance)} $rrSymbol",
            subtitle: "Balance",
            reversed: true,
          ),

        if (showBalance) const SizedBox(width: 20),

        if (showBalance)
          WidgetsHeader(
            titleColor: plColor,
            title:
                "${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfit)} $srSymbol (${_rProfit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_rProfitPercentage, maxDecimals: 2)}%)",
            subtitle: "Return (%)",
            reversed: true,
          ),
      ],
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

    final tx = widget.tx;
    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetsHeader(titleColor: _fgColor, title: "${Utils.formatSmartDouble(_capital)} $srSymbol", subtitle: "Capital", reversed: true),
        const SizedBox(width: 15),
        WidgetsHeader(titleColor: _fgColor, title: "${Utils.formatSmartDouble(_balance)} $srSymbol", subtitle: "Balance", reversed: true),
        const SizedBox(width: 15),
        WidgetsHeader(
          titleColor: plColor,
          title:
              "${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profit)} $srSymbol (${_profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(_profitPercentage, maxDecimals: 2)}%)",
          subtitle: "Return (%)",
          reversed: true,
        ),
      ],
    );
  }

  Widget _buildMiddleGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _branchAmounts.entries.map((entry) {
        final symbol = _cryptosController.getSymbol(entry.key) ?? '';
        final amount = Utils.formatSmartDouble(entry.value);

        return Padding(
          padding: const EdgeInsets.only(right: 25),
          child: WidgetsHeader(titleColor: _fgColor, title: amount, subtitle: symbol, reversed: true),
        );
      }).toList(),
    );
  }
}

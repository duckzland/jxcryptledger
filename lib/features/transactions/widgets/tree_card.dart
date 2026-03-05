import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../cryptos/controller.dart';
import 'buttons.dart';
import '../model.dart';
import '../controller.dart';
import '../../../widgets/header.dart';

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

  final leftKey = GlobalKey();
  final rightKey = GlobalKey();
  final middleKey = GlobalKey();
  final trailingKey = GlobalKey();

  double leftWidth = 0;
  double rightWidth = 0;
  double middleWidth = 0;
  double trailingWidth = 0;

  bool wrapMiddle = false;

  bool loading = true;
  bool hasLeaf = false;

  double capital = 0;
  double balance = 0;
  double profit = 0;
  double profitPercentage = 0;

  Map<int, double> branchAmounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tx = widget.tx;

    final results = await Future.wait([
      _txController.collectBranchTotalResultAmount(tx),
      _txController.hasLeaf(tx),
      _txController.collectBranchActiveAmount(tx),
    ]);

    final totalResult = results[0] as double;
    final leaf = results[1] as bool;
    final branch = results[2] as Map<int, double>;

    final cap = tx.srAmount;
    final bal = totalResult;
    final prof = bal - cap;
    final profPct = cap == 0 ? 0 : (prof / cap) * 100;

    setState(() {
      hasLeaf = leaf;
      capital = cap;
      balance = bal;
      profit = prof;
      profitPercentage = profPct as double;
      branchAmounts = branch;
      loading = false;
    });
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lw = leftKey.currentContext?.size?.width ?? 0;
      final rw = rightKey.currentContext?.size?.width ?? 0;
      final mw = middleKey.currentContext?.size?.width ?? 0;
      final tw = trailingKey.currentContext?.size?.width ?? 0;

      if (tw != trailingWidth) {
        setState(() => trailingWidth = tw);
      }

      if (lw != leftWidth || rw != rightWidth || mw != middleWidth) {
        setState(() {
          leftWidth = lw;
          rightWidth = rw;
          middleWidth = mw;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted || loading) return const SizedBox.shrink();

    final tx = widget.tx;

    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? '';
    final rrSymbol = _cryptosController.getSymbol(tx.rrId) ?? '';

    Color bgColor = AppTheme.rowHeaderBg;
    Color fgColor = AppTheme.text;

    if (tx.statusEnum == TransactionStatus.inactive) {
      bgColor = AppTheme.mutedBg;
      fgColor = AppTheme.textMuted;
    }
    if (tx.statusEnum == TransactionStatus.closed) {
      bgColor = AppTheme.closedBg;
      fgColor = AppTheme.textMuted;
    }

    Color plColor = fgColor;
    if (profitPercentage > 0) {
      plColor = const Color.fromARGB(255, 112, 225, 104);
    } else if (profitPercentage < 0) {
      plColor = const Color.fromARGB(255, 255, 109, 109);
    }

    // Centralized padding config
    const padMiddle = EdgeInsets.only(left: 20, right: 20, top: 0);
    const padRight = EdgeInsets.only(left: 20, right: 0, top: 0);
    const padTrail = EdgeInsets.only(left: 20, right: 25, top: 6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        _measure();

        final remaining = totalWidth - leftWidth - rightWidth - trailingWidth;
        final shouldWrapMiddle = middleWidth > remaining && remaining > 0;

        final leftGroup = _buildLeftGroup(fgColor, tx, srSymbol, rrSymbol);
        final rightGroup = _buildRightGroup(fgColor, plColor, capital, balance, profit, profitPercentage, srSymbol, hasLeaf);
        final middleGroup = _buildMiddleGroup(fgColor, branchAmounts, _cryptosController);

        return Card(
          margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
          color: bgColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!shouldWrapMiddle)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leftGroup,

                                Padding(padding: padMiddle, child: middleGroup),

                                Expanded(
                                  child: Padding(
                                    padding: padRight,
                                    child: Align(alignment: Alignment.centerRight, child: rightGroup),
                                  ),
                                ),
                              ],
                            ),

                          if (shouldWrapMiddle)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    leftGroup,

                                    Expanded(
                                      child: Padding(
                                        padding: padRight,
                                        child: Align(alignment: Alignment.centerRight, child: rightGroup),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                middleGroup,
                              ],
                            ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: padTrail,
                      child: TransactionsButtons(tx: tx, onAction: widget.onAction),
                    ),
                  ],
                ),

                Offstage(
                  child: Container(key: leftKey, child: leftGroup),
                ),

                Offstage(
                  child: Padding(key: middleKey, padding: padMiddle, child: middleGroup),
                ),

                Offstage(
                  child: Padding(key: rightKey, padding: padRight, child: rightGroup),
                ),

                Offstage(
                  child: Padding(
                    key: trailingKey,
                    padding: padTrail,
                    child: TransactionsButtons(tx: tx, onAction: widget.onAction),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftGroup(Color fgColor, TransactionsModel tx, String srSymbol, String rrSymbol) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetsHeader(
          titleColor: fgColor,
          title: "${tx.srAmountText} $srSymbol → ${tx.rrAmountText} $rrSymbol",
          subtitle: tx.timestampAsFormattedDate,
          reversed: true,
        ),
        const SizedBox(width: 20),
        WidgetsHeader(titleColor: fgColor, title: tx.statusText, subtitle: "Status", reversed: true),
        const SizedBox(width: 20),
        WidgetsHeader(titleColor: fgColor, title: "${tx.balanceText} $rrSymbol", subtitle: "Available", reversed: true),
      ],
    );
  }

  Widget _buildRightGroup(
    Color fgColor,
    Color plColor,
    double capital,
    double balance,
    double profit,
    double profitPercentage,
    String srSymbol,
    bool hasLeaf,
  ) {
    if (!hasLeaf || balance <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetsHeader(titleColor: fgColor, title: "${Utils.formatSmartDouble(capital)} $srSymbol", subtitle: "Capital", reversed: true),
        const SizedBox(width: 15),
        WidgetsHeader(titleColor: fgColor, title: "${Utils.formatSmartDouble(balance)} $srSymbol", subtitle: "Balance", reversed: true),
        const SizedBox(width: 15),
        WidgetsHeader(
          titleColor: plColor,
          title:
              "${profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(profit)} $srSymbol (${profit >= 0 ? '+' : ''}${Utils.formatSmartDouble(profitPercentage, maxDecimals: 2)}%)",
          subtitle: "Return (%)",
          reversed: true,
        ),
      ],
    );
  }

  Widget _buildMiddleGroup(Color fgColor, Map<int, double> branchAmounts, CryptosController cryptos) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: branchAmounts.entries.map((entry) {
        final symbol = cryptos.getSymbol(entry.key) ?? '';
        final amount = Utils.formatSmartDouble(entry.value);

        return Padding(
          padding: const EdgeInsets.only(right: 25),
          child: WidgetsHeader(titleColor: fgColor, title: amount, subtitle: symbol, reversed: true),
        );
      }).toList(),
    );
  }
}

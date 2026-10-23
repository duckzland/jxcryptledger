import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../widgets/numbers/flow.dart';
import '../../../widgets/text/selectable.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsWidgetsBalanceBar extends StatefulWidget {
  final ValueNotifier<List<String>> data;
  final bool initialShowAmountUsed;
  final ValueChanged<bool>? onToggle;

  const TransactionsWidgetsBalanceBar({super.key, required this.data, this.initialShowAmountUsed = false, this.onToggle});

  @override
  State<TransactionsWidgetsBalanceBar> createState() => _TransactionsWidgetsBalanceBarState();
}

class _TransactionsWidgetsBalanceBarState extends State<TransactionsWidgetsBalanceBar> {
  late bool _showAmountUsed = widget.initialShowAmountUsed;

  TransactionsController get txController => CoreLocator.getit<TransactionsController>();
  RatesController get rateController => CoreLocator.getit<RatesController>();
  CryptosController get cryptosController => CoreLocator.getit<CryptosController>();

  @override
  void didUpdateWidget(covariant TransactionsWidgetsBalanceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialShowAmountUsed != widget.initialShowAmountUsed) {
      _showAmountUsed = widget.initialShowAmountUsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snackTheme = Theme.of(context).snackBarTheme;
    final textStyle = snackTheme.contentTextStyle?.copyWith(fontWeight: AppTheme.notifyFontWeight, fontSize: AppTheme.notifyFontSize);

    return ListenableBuilder(
      listenable: Listenable.merge([rateController, widget.data]),
      builder: (context, _) {
        final txIds = widget.data.value;
        final amount = _calculateAmount(txIds);

        if (txIds.isEmpty || amount.isEmpty) {
          return const SizedBox.shrink();
        }

        final used = _showAmountUsed ? _populateAmount(txIds) : _populateCapital(txIds);

        return Positioned(
          left: 6,
          right: 6,
          bottom: 3,
          child: Material(
            elevation: snackTheme.elevation!,
            color: AppTheme.darkPurple,
            shape: snackTheme.shape,
            child: Padding(
              padding: snackTheme.insetPadding!,
              child: Row(
                spacing: 12,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${txIds.length} transactions selected", style: textStyle),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: _showAmountUsed ? "Show capital used" : "Show amount used",
                    icon: Icon(
                      _showAmountUsed ? Icons.account_balance_wallet : Icons.payments,
                      color: snackTheme.contentTextStyle?.color,
                      size: AppTheme.notifyFontSize,
                    ),
                    onPressed: _toggleInfoDisplay,
                  ),
                  Expanded(
                    child: (used.isNotEmpty)
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: WidgetsTextSelectable(used.join("   "), textAlign: TextAlign.center),
                          )
                        : const SizedBox.shrink(),
                  ),
                  WidgetsNumbersFlow(begin: amount.toString(), end: amount.toString(), suffix: " USDT", style: textStyle!),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: snackTheme.contentTextStyle?.color, size: AppTheme.notifyFontSize),
                    onPressed: () {
                      widget.data.value = [];
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleInfoDisplay() {
    final showAmountUsed = !_showAmountUsed;
    setState(() => _showAmountUsed = showAmountUsed);
    widget.onToggle?.call(showAmountUsed);
  }

  List<String> _populateCapital(List<String> txsIds) {
    final ids = txsIds = txsIds.toSet().toList();
    final txsMap = txController.getIndexedMap();
    final calc = TransactionCalculation();
    final capitalUsed = {};
    final List<TransactionsModel> txs = [];

    for (final uuid in ids) {
      final tx = txController.get(uuid);
      if (tx != null) {
        txs.add(tx);
      }
    }

    for (final tx in txs) {
      final ctx = tx.isRoot ? tx : txsMap[tx.rid];
      if (ctx == null) continue;
      capitalUsed[ctx.srId] = Math.add(
        capitalUsed[ctx.srId] ?? Decimal.zero,
        tx.isRoot
            ? (Math.multiply(tx.srAmount, (tx.balance >= tx.rrAmount) ? Decimal.one : Math.divide(tx.balance, tx.rrAmount)))
            : calc.totalCapitalUsed(tx, txsMap: txsMap),
      );
    }

    List<String> cptUsed = [];
    for (final entry in capitalUsed.entries) {
      final symbol = cryptosController.getSymbol(entry.key) ?? 'Unknown Coin';
      cptUsed.add("${Utils.formatSmartDecimal(entry.value)} $symbol");
    }

    return cptUsed;
  }

  List<String> _populateAmount(List<String> txsIds) {
    final ids = txsIds.toSet().toList();
    final amountUsed = {};
    final List<TransactionsModel> txs = [];

    for (final uuid in ids) {
      final tx = txController.get(uuid);
      if (tx != null) {
        txs.add(tx);
      }
    }

    for (final tx in txs) {
      amountUsed[tx.rrId] = Math.add(amountUsed[tx.rrId] ?? Decimal.zero, tx.balance);
    }

    final List<String> result = [];
    for (final entry in amountUsed.entries) {
      final symbol = cryptosController.getSymbol(entry.key) ?? 'Unknown Coin';
      result.add("${Utils.formatSmartDecimal(entry.value)} $symbol");
    }

    return result;
  }

  String _calculateAmount(List<String> txsIds) {
    final ids = txsIds = txsIds.toSet().toList();
    final List<TransactionsModel> txs = [];

    for (final uuid in ids) {
      final tx = txController.get(uuid);
      if (tx != null) {
        txs.add(tx);
      }
    }

    Decimal balance = Decimal.zero;

    for (final tx in txs) {
      final rate = rateController.getStoredRate(tx.rrId, 825);
      if (rate <= Decimal.zero) {
        rateController.addQueue(tx.rrId, 825, force: true);
        continue;
      }

      balance = Math.add(balance, Math.multiply(tx.balance, rate));
    }

    return (balance > Decimal.zero) ? Utils.formatSmartDecimal(balance) : "";
  }
}

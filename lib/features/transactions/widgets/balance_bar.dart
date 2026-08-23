import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../widgets/numbers/flow.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsWidgetsBalanceBar extends StatelessWidget {
  final ValueNotifier<List<String>> data;
  const TransactionsWidgetsBalanceBar({super.key, required this.data});

  TransactionsController get txController => CoreLocator.getit<TransactionsController>();
  RatesController get rateController => CoreLocator.getit<RatesController>();
  CryptosController get cryptosController => CoreLocator.getit<CryptosController>();

  @override
  Widget build(BuildContext context) {
    final snackTheme = Theme.of(context).snackBarTheme;
    final textStyle = snackTheme.contentTextStyle?.copyWith(fontWeight: AppTheme.notifyFontWeight, fontSize: AppTheme.notifyFontSize);

    return ListenableBuilder(
      listenable: Listenable.merge([rateController, data]),
      builder: (context, _) {
        final txIds = data.value;
        final amount = _calculateAmount(txIds);

        if (txIds.isEmpty || amount.isEmpty) {
          return const SizedBox.shrink();
        }

        final cptUsed = _populateCapital(txIds);

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
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${txIds.length} transactions selected", style: textStyle),
                  Expanded(
                    child: (cptUsed.isNotEmpty) ? WidgetsText(cptUsed.join("  •  "), textAlign: TextAlign.center) : const SizedBox.shrink(),
                  ),
                  WidgetsNumbersFlow(begin: amount.toString(), end: amount.toString(), suffix: " USDT", style: textStyle!),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: snackTheme.contentTextStyle?.color, size: AppTheme.notifyFontSize),
                    onPressed: () {
                      data.value = [];
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
      final txUsed = capitalUsed[ctx.srId] ?? Decimal.zero;
      capitalUsed[ctx.srId] = Math.add(txUsed, calc.totalCapitalUsed(tx, txsMap: txsMap));
    }

    List<String> cptUsed = [];
    for (final entry in capitalUsed.entries) {
      final symbol = cryptosController.getSymbol(entry.key) ?? 'Unknown Coin';
      cptUsed.add("${Utils.formatSmartDecimal(entry.value)} $symbol");
    }

    return cptUsed;
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

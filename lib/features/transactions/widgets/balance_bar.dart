import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../rates/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsWidgetsBalanceBar extends StatelessWidget {
  final ValueNotifier<List<String>> data;
  const TransactionsWidgetsBalanceBar({super.key, required this.data});

  TransactionsController get txController => CoreLocator.getit<TransactionsController>();
  RatesController get rateController => CoreLocator.getit<RatesController>();

  @override
  Widget build(BuildContext context) {
    final snackTheme = Theme.of(context).snackBarTheme;
    final textStyle = snackTheme.contentTextStyle?.copyWith(fontWeight: AppTheme.notifyFontWeight, fontSize: AppTheme.notifyFontSize);

    return ValueListenableBuilder<List<String>>(
      valueListenable: data,
      builder: (context, txIds, _) {
        final amount = _calculateAmount(txIds);

        if (txIds.isEmpty || amount.isEmpty) {
          return const SizedBox.shrink();
        }

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
                  Expanded(child: Text("${txIds.length} transactions selected", style: textStyle)),

                  Text("$amount USDT", style: textStyle),

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

  String _calculateAmount(List<String> txsIds) {
    final ids = txsIds = txsIds.toSet().toList();

    List<TransactionsModel> txs = [];

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
        continue;
      }

      balance = Math.add(balance, Math.multiply(tx.balance, rate));
    }

    return (balance > Decimal.zero) ? Utils.formatSmartDecimal(balance) : "";
  }
}

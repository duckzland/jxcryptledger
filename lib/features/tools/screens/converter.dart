import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/math.dart';
import '../../../mixins/rateable.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/fields/amount.dart';
import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/header.dart';
import '../../cryptos/controller.dart';
import '../../../widgets/fields/crypto_search.dart';

class ToolsConverterView extends StatefulWidget {
  const ToolsConverterView({super.key});

  @override
  State<ToolsConverterView> createState() => _ToolsConverterViewState();
}

class _ToolsConverterViewState extends State<ToolsConverterView> with MixinsRateable<ToolsConverterView> {
  late final CryptosController _cryptosController;

  String? _sourceAmount;
  Decimal? _reversedRate;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();
    _sourceAmount = null;
    _reversedRate = null;

    rateableWithField = false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: WidgetsHeader(subtitle: "From:", subtitleFontSize: 13, spacing: 10, child: _buildSourceAmountField()),
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: WidgetsHeader(subtitle: " ", subtitleFontSize: 13, spacing: 10, child: _buildSourceCryptoField()),
                    ),

                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 38), child: Icon(Icons.arrow_forward, size: 24)),

                    Expanded(
                      child: WidgetsHeader(subtitle: "To:", subtitleFontSize: 13, spacing: 10, child: _buildResultCryptoField()),
                    ),

                    const SizedBox(width: 10),

                    WidgetsHeader(
                      subtitle: " ",
                      subtitleFontSize: 13,
                      spacing: 10,
                      child: WidgetsButtonsAction(
                        icon: Icons.swap_horiz,
                        tooltip: "Convert",
                        padding: const EdgeInsets.all(0),
                        iconSize: 24,
                        minimumSize: const Size(52, 52),
                        initialState: WidgetsButtonActionState.action,
                        filledMode: true,
                        evaluator: (s) {
                          final int source = rateableSource ?? -1;
                          final int target = rateableTarget ?? -1;
                          final double amount = _sourceAmount == null ? -1 : double.tryParse(Utils.sanitizeNumber(_sourceAmount!)) ?? -1;

                          if (source < 0 || target < 0 || amount < 0) {
                            s.disable();
                          } else {
                            s.action();
                          }
                        },
                        onPressed: (_) {
                          rateableGetRate(silent: true);
                        },
                      ),
                    ),
                  ],
                ),

                _buildCalculatedResult(),

                const SizedBox(height: 28),
              ],
            );
          } else {
            return Wrap(
              direction: Axis.horizontal,
              runSpacing: 20,
              spacing: 10,
              runAlignment: WrapAlignment.center,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                WidgetsHeader(title: "From:", spacing: 10, children: [_buildSourceAmountField(), _buildSourceCryptoField()]),

                WidgetsHeader(title: "To:", spacing: 10, child: _buildResultCryptoField()),

                WidgetsButtonsAction(
                  label: "Convert",
                  iconSize: 24,
                  initialState: WidgetsButtonActionState.action,
                  filledMode: true,
                  evaluator: (s) {
                    final int source = rateableSource ?? -1;
                    final int target = rateableTarget ?? -1;
                    final double amount = _sourceAmount == null ? -1 : double.tryParse(Utils.sanitizeNumber(_sourceAmount!)) ?? -1;

                    if (source < 0 || target < 0 || amount < 0) {
                      s.disable();
                    } else {
                      s.action();
                    }
                  },
                  onPressed: (_) {
                    rateableGetRate(silent: true);
                  },
                ),

                const SizedBox(height: 50),
                _buildCalculatedResult(mini: true),
                const SizedBox(height: 28),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSourceAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 1.5',
      onChanged: (value) {
        _sourceAmount = value;
        rateableGetRate();
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      onSelected: (id) => setState(() {
        int source = rateableSource ?? -1;

        if (id != source) {
          rateableValue = null;
          _reversedRate = null;
        }

        rateableSource = id;

        rateableGetRate(refresh: false, silent: true);
      }),
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      onSelected: (id) => setState(() {
        int target = rateableTarget ?? -1;

        if (id != target) {
          rateableValue = null;
          _reversedRate = null;
        }

        rateableTarget = id;

        rateableGetRate(refresh: false, silent: true);
      }),
    );
  }

  Widget _buildCalculatedResult({bool mini = false}) {
    final Decimal source = _sourceAmount == null ? Decimal.zero : Decimal.tryParse(Utils.sanitizeNumber(_sourceAmount!)) ?? Decimal.zero;
    final Decimal rate = rateableValue ?? Decimal.fromInt(-1);
    final Decimal reversedRate = _reversedRate ?? Decimal.fromInt(-1);
    final String sourceSymbol = rateableSource != null ? _cryptosController.getSymbol(rateableSource!) ?? "UNK" : "UNK";
    final String targetSymbol = rateableTarget != null ? _cryptosController.getSymbol(rateableTarget!) ?? "UNK" : "UNK";

    if (source <= Decimal.zero ||
        rate < Decimal.zero ||
        reversedRate < Decimal.zero ||
        sourceSymbol == "UNK" ||
        targetSymbol == "UNK" ||
        targetSymbol == "" ||
        sourceSymbol == "") {
      return const Text("");
    }

    final Decimal resultValue = source * rate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "${Utils.formatSmartDecimal(source)} $sourceSymbol to $targetSymbol",
          style: TextStyle(fontSize: mini ? 13 : 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "${Utils.formatSmartDecimal(resultValue)} $targetSymbol",
          style: TextStyle(fontSize: mini ? 28 : 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        Text(
          "1 $targetSymbol = ${Utils.formatSmartDecimal(rate)} $sourceSymbol",
          style: TextStyle(fontSize: mini ? 12 : 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        Text(
          "1 $sourceSymbol = ${Utils.formatSmartDecimal(reversedRate)} $targetSymbol",
          style: TextStyle(fontSize: mini ? 11 : 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
      ],
    );
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    if (rateableValue != null && rateableValue! > Decimal.zero) {
      _reversedRate = Math.divide(Decimal.one, rateableValue!);
    }
  }
}

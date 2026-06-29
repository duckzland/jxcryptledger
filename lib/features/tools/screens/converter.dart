import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/math.dart';
import '../../../mixins/rateable.dart';
import '../../../widgets/button.dart';
import '../../../widgets/fields/amount.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/panel.dart';
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
  double? _reversedRate;

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
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCryptoInputColumn("From:", _buildSourceAmountField())),

                          Expanded(child: _buildCryptoInputColumn("", _buildSourceCryptoField())),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55),
                            child: Icon(Icons.arrow_forward, size: 24),
                          ),

                          Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField())),

                          const SizedBox(width: 20),

                          _buildCryptoInputColumn(
                            "",
                            WidgetsButton(
                              icon: Icons.swap_horiz,
                              tooltip: "Convert",
                              padding: const EdgeInsets.all(0),
                              iconSize: 24,
                              minimumSize: const Size(54, 54),
                              evaluator: (s) {
                                final int source = rateableSource ?? -1;
                                final int target = rateableTarget ?? -1;
                                final double amount = _sourceAmount == null ? -1 : double.tryParse(_sourceAmount!) ?? -1;

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
                      Row(
                        children: [
                          Expanded(child: _buildCryptoInputColumn("From:", _buildSourceAmountField())),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCryptoInputColumn("", _buildSourceCryptoField())),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField())),
                          const SizedBox(width: 10),
                          _buildCryptoInputColumn(
                            "",
                            WidgetsButton(
                              icon: Icons.swap_horiz,
                              tooltip: "Convert",
                              padding: const EdgeInsets.all(0),
                              iconSize: 24,
                              minimumSize: const Size(54, 54),
                              evaluator: (s) {
                                final int source = rateableSource ?? -1;
                                final int target = rateableTarget ?? -1;
                                final double amount = _sourceAmount == null ? -1 : double.tryParse(_sourceAmount!) ?? -1;

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

                      const SizedBox(height: 20),
                      _buildCalculatedResult(),
                      const SizedBox(height: 28),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoInputColumn(String label, Widget amountField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 20),
        amountField,
      ],
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

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount == null ? 0.0 : double.tryParse(_sourceAmount!) ?? 0;
    final double rate = rateableValue ?? -1;
    final double reversedRate = _reversedRate ?? -1;
    final String sourceSymbol = rateableSource != null ? _cryptosController.getSymbol(rateableSource!) ?? "UNK" : "UNK";
    final String targetSymbol = rateableTarget != null ? _cryptosController.getSymbol(rateableTarget!) ?? "UNK" : "UNK";

    if (source <= 0 ||
        rate < 0 ||
        reversedRate < 0 ||
        sourceSymbol == "UNK" ||
        targetSymbol == "UNK" ||
        targetSymbol == "" ||
        sourceSymbol == "") {
      return const Text("");
    }

    final double resultValue = source * rate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "${Utils.formatSmartDouble(source)} $sourceSymbol to $targetSymbol",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "${Utils.formatSmartDouble(resultValue)} $targetSymbol",
          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        Text(
          "1 $targetSymbol = ${Utils.formatSmartDouble(rate)} $sourceSymbol",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        Text(
          "1 $sourceSymbol = ${Utils.formatSmartDouble(reversedRate)} $targetSymbol",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
      ],
    );
  }

  @override
  void rateableGetCallback() {
    if (rateableValue != null && rateableValue! > 0) {
      _reversedRate = Math.divide(1, rateableValue!);
    }
  }
}

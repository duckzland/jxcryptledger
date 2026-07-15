import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../mixins/rateable.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../../widgets/fields/crypto_search.dart';

class ToolsCalculatorView extends StatefulWidget {
  const ToolsCalculatorView({super.key});

  @override
  State<ToolsCalculatorView> createState() => _ToolsCalculatorViewState();
}

class _ToolsCalculatorViewState extends State<ToolsCalculatorView> with MixinsRateable<ToolsCalculatorView> {
  late final CryptosController _cryptosController;

  String? _sourceAmount;
  String? _ratesRevertAmount;

  late final TextEditingController _rateController;
  late final TextEditingController _rateRevertController;

  Timer? _debounce;

  bool _isReversed = false;

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();
    _sourceAmount = null;
    _ratesRevertAmount = null;

    _rateController = TextEditingController();
    _rateRevertController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _rateController.dispose();
    _rateRevertController.dispose();
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

                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55), child: Icon(Icons.clear, size: 24)),

                          Expanded(child: _buildCryptoInputColumn("Sell Rate:", _buildRatesAmountField())),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55),
                            child: Icon(Icons.swap_horiz, size: 24),
                          ),

                          Expanded(child: _buildCryptoInputColumn("Buyback Rate:", _buildRatesRevertAmountField())),
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
                      Row(children: [Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField()))]),
                      Row(
                        children: [
                          Expanded(child: _buildCryptoInputColumn("Sell Rate:", _buildRatesAmountField())),
                          const SizedBox(width: 10),
                          Expanded(child: _buildCryptoInputColumn("Buyback Rate:", _buildRatesRevertAmountField())),
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

  Widget _buildRatesRevertAmountField() {
    return WidgetsFieldsAmount(
      title: 'Rate',
      helperText: 'e.g., 10.5',
      controller: _rateRevertController,
      allowReverse: true,
      disposeController: false,
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        if (_ratesRevertAmount != value) {
          _debounce = Timer(const Duration(milliseconds: 100), () {
            setState(() {
              _ratesRevertAmount = value;
            });
          });
        }
      },
      onReversing: () {
        setState(() {
          _isReversed = !_isReversed;

          _ratesRevertAmount = rateableParseToString(_ratesRevertAmount!, reverse: true);

          if (rateableAmount != null) {
            rateableAmount = rateableParseToString(rateableAmount!, reverse: true);
            _rateController.text = rateableAmount!;
          }
        });
      },
    );
  }

  Widget _buildRatesAmountField() {
    return WidgetsFieldsAmount(
      title: 'Rate',
      helperText: 'e.g., 10.5',
      controller: _rateController,
      allowReverse: true,
      allowRate: rateableAllow,
      disposeController: false,
      onRetrievingRate: (void Function(String value, String helperText) updateState) {
        // Store the callback to act as promise contract!
        rateableStateUpdater = updateState;
        rateableStateUpdater?.call("", "Retrieving rate...");
        rateableGetRate(reversed: _isReversed);
      },
      onChanged: (value) {
        // Nullify the promise contract!
        rateableStateUpdater = null;

        if (_debounce?.isActive ?? false) _debounce!.cancel();

        if (rateableAmount != value) {
          _debounce = Timer(const Duration(milliseconds: 100), () {
            setState(() {
              rateableAmount = value;
            });
          });
        }
      },
      onReversing: () {
        setState(() {
          _isReversed = !_isReversed;

          rateableAmount = rateableParseToString(rateableAmount!, reverse: true);

          if (_ratesRevertAmount != null) {
            _ratesRevertAmount = rateableParseToString(_ratesRevertAmount!, reverse: true);
            _rateRevertController.text = _ratesRevertAmount!;
          }
        });
      },
    );
  }

  Widget _buildSourceAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 1.5',
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {
            _sourceAmount = value;
          });
        });
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => rateableSource = id));
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => rateableTarget = id));
  }

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount == null ? 0.0 : double.tryParse(_sourceAmount!) ?? 0;
    final String sourceSymbol = rateableSource != null ? _cryptosController.getSymbol(rateableSource!) ?? "" : "";
    final String targetSymbol = rateableTarget != null ? _cryptosController.getSymbol(rateableTarget!) ?? "" : "";

    final double entryRate = rateableAmount == null ? 0.0 : rateableParseToDouble(rateableAmount!, reverse: _isReversed);
    final double returnRate = _ratesRevertAmount == null ? 0.0 : rateableParseToDouble(_ratesRevertAmount!, reverse: _isReversed);

    if (source <= 0 || entryRate <= 0 || targetSymbol == "UNK" || sourceSymbol == "UNK" || targetSymbol == "" || sourceSymbol == "") {
      return const Text("");
    }

    final double stage1Balance = source * entryRate;
    double resultValue = stage1Balance;
    double profit = 0;

    if (returnRate > 0) {
      resultValue = stage1Balance / returnRate;
      profit = resultValue - source;
    }

    final String currentSymbol = (returnRate > 0) ? sourceSymbol : targetSymbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          returnRate > 0 ? "Returned amout" : "Calculated Amount",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "${Utils.formatSmartDouble(resultValue)} $currentSymbol",
          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),

        if (returnRate > 0 && profit != 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.tableRowBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.separator),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                Text("Net Profit/Loss:", style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                const SizedBox(width: 8),
                WidgetsBalanceText(
                  text: "${Utils.formatSmartDouble(profit)} $sourceSymbol",
                  value: resultValue,
                  comparator: source,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  hidePrefix: profit < 0,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

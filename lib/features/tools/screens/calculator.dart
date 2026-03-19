import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
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

class _ToolsCalculatorViewState extends State<ToolsCalculatorView> {
  late final CryptosController _cryptosController;

  int? _selectedSource;
  int? _selectedTarget;

  String? _sourceAmount;
  String? _ratesAmount;
  String? _ratesRevertAmount;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();

    _selectedSource = null;
    _selectedTarget = null;
    _sourceAmount = null;
    _ratesAmount = null;
    _ratesRevertAmount = null;
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
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {
            _ratesRevertAmount = value;
          });
        });
      },
    );
  }

  Widget _buildRatesAmountField() {
    return WidgetsFieldsAmount(
      title: 'Rate',
      helperText: 'e.g., 10.5',
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {
            _ratesAmount = value;
          });
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
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => _selectedSource = id));
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => _selectedTarget = id));
  }

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount == null ? 0.0 : double.tryParse(_sourceAmount!) ?? 0;
    final double entryRate = _ratesAmount == null ? 0.0 : double.tryParse(_ratesAmount!) ?? 0;
    final double returnRate = _ratesRevertAmount == null ? 0.0 : double.tryParse(_ratesRevertAmount!) ?? 0;

    if (source <= 0 || entryRate <= 0) {
      return Text("");
    }

    final double stage1Balance = source * entryRate;
    double resultValue = stage1Balance;
    double profit = 0;

    if (returnRate > 0) {
      resultValue = stage1Balance / returnRate;
      profit = resultValue - source;
    }

    final String sourceSymbol = _selectedSource != null ? _cryptosController.getSymbol(_selectedSource!) ?? "" : "";
    final String targetSymbol = _selectedTarget != null ? _cryptosController.getSymbol(_selectedTarget!) ?? "" : "";
    final String currentSymbol = (returnRate > 0) ? sourceSymbol : targetSymbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          returnRate > 0 ? "Returned amout" : "Calculated Amount",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "${Utils.formatSmartDouble(resultValue)} $currentSymbol",
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),

        if (returnRate > 0 && profit != 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.rowHeaderBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.separator),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                Text("Net Profit/Loss:", style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
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

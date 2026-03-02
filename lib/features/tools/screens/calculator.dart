import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/rates/controller.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../cryptos/search_field.dart';

class ToolsCalculatorView extends StatefulWidget {
  const ToolsCalculatorView({super.key});

  @override
  State<ToolsCalculatorView> createState() => _ToolsCalculatorViewState();
}

class _ToolsCalculatorViewState extends State<ToolsCalculatorView> {
  late final CryptosController _cryptosController;

  late TextEditingController _sourceAmountController;
  late TextEditingController _ratesAmountController;
  late TextEditingController _ratesRevertAmountController;

  int? _selectedSource;
  int? _selectedTarget;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();

    _sourceAmountController = TextEditingController();

    _ratesAmountController = TextEditingController();
    _ratesRevertAmountController = TextEditingController();

    _selectedSource = null;
    _selectedTarget = null;
  }

  @override
  void dispose() {
    _sourceAmountController.dispose();
    _ratesAmountController.dispose();
    _ratesRevertAmountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ToolsCalculatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCryptoInputColumn("From:", _buildSourceAmountField())),

                    Expanded(child: _buildCryptoInputColumn("", _buildSourceCryptoField())),

                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55), child: Icon(Icons.arrow_forward, size: 24)),

                    Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField())),

                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55), child: Icon(Icons.clear, size: 24)),

                    Expanded(child: _buildCryptoInputColumn("With Rate:", _buildRatesAmountField())),

                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 55), child: Icon(Icons.swap_horiz, size: 24)),

                    Expanded(child: _buildCryptoInputColumn("Revert with Rate:", _buildRatesRevertAmountField())),
                  ],
                ),

                _buildCalculatedResult(),

                const SizedBox(height: 28),
              ],
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
    return TextFormField(
      controller: _ratesRevertAmountController,
      decoration: _input('Rate', 'e.g., 10.5'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {});
        });
      },
    );
  }

  Widget _buildRatesAmountField() {
    return TextFormField(
      controller: _ratesAmountController,
      decoration: _input('Rate', 'e.g., 10.5'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {});
        });
      },
    );
  }

  Widget _buildSourceAmountField() {
    return TextFormField(
      controller: _sourceAmountController,
      decoration: _input('Amount', 'e.g., 1.5'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {});
        });
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return CryptoSearchField(
      labelText: 'Coin',
      initialValue: null,
      validator: _validateCrypto,
      onSelected: (id) => setState(() => _selectedSource = id),
    );
  }

  Widget _buildResultCryptoField() {
    return CryptoSearchField(
      labelText: 'Coin',
      initialValue: null,
      validator: _validateCrypto,
      onSelected: (id) => setState(() => _selectedTarget = id),
    );
  }

  Widget _buildCalculatedResult() {
    final double source = double.tryParse(_sourceAmountController.text) ?? 0;
    final double entryRate = double.tryParse(_ratesAmountController.text) ?? 0;
    final double returnRate = double.tryParse(_ratesRevertAmountController.text) ?? 0;

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

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }

    String val = Utils.sanitizeNumber(value);

    final parsed = double.tryParse(val);
    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }

    // if (parsed > 1e12) {
    //   return 'Amount is unrealistically large';
    // }

    return null;
  }

  String? _validateCrypto(int? value) {
    if (value == null || value == 0) {
      return 'Crypto is required';
    }

    if (_cryptosController.getSymbol(value) == null) {
      return 'Invalid crypto';
    }

    return null;
  }
}

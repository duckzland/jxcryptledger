import 'dart:async';

import 'package:flutter/material.dart';

import '../../../widgets/button.dart';
import '../../../widgets/fields/amount.dart';
import '../../rates/controller.dart';
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

class _ToolsConverterViewState extends State<ToolsConverterView> {
  late final CryptosController _cryptosController;
  late final RatesController _ratesController;

  final List<(int source, int target)> _temporaryRates = [];

  int? _selectedSource;
  int? _selectedTarget;
  String? _sourceAmount;

  double? _rate;
  double? _reversedRate;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();
    _ratesController = locator<RatesController>();

    _selectedSource = null;
    _selectedTarget = null;
    _sourceAmount = null;

    _rate = null;
    _reversedRate = null;

    _ratesController.addListener(_onRatesUpdated);
  }

  @override
  void dispose() {
    _ratesController.removeListener(_onRatesUpdated);
    _debounce?.cancel();
    _cleanTemporaryRates();

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
                                final int source = _selectedSource ?? -1;
                                final int target = _selectedTarget ?? -1;
                                final double amount = _sourceAmount == null ? -1 : double.tryParse(_sourceAmount!) ?? -1;

                                if (source < 0 || target < 0 || amount < 0) {
                                  s.disable();
                                } else {
                                  s.action();
                                }
                              },
                              onPressed: (_) {
                                setState(() {
                                  _getRate();
                                });
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
                                final int source = _selectedSource ?? -1;
                                final int target = _selectedTarget ?? -1;
                                final double amount = _sourceAmount == null ? -1 : double.tryParse(_sourceAmount!) ?? -1;

                                if (source < 0 || target < 0 || amount < 0) {
                                  s.disable();
                                } else {
                                  s.action();
                                }
                              },
                              onPressed: (_) {
                                setState(() {
                                  _getRate();
                                });
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
        _getRate();
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      onSelected: (id) => setState(() {
        int source = _selectedSource ?? -1;

        if (id != source) {
          _rate = null;
          _reversedRate = null;
        }

        _selectedSource = id;

        _getRate();
      }),
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      onSelected: (id) => setState(() {
        int target = _selectedTarget ?? -1;

        if (id != target) {
          _rate = null;
          _reversedRate = null;
        }

        _selectedTarget = id;

        _getRate();
      }),
    );
  }

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount == null ? 0.0 : double.tryParse(_sourceAmount!) ?? 0;
    final double rate = _rate ?? -1;
    final double reversedRate = _reversedRate ?? -1;

    if (source <= 0 || rate < 0 || reversedRate < 0) {
      return Text("");
    }

    final String sourceSymbol = _selectedSource != null ? _cryptosController.getSymbol(_selectedSource!) ?? "" : "";
    final String targetSymbol = _selectedTarget != null ? _cryptosController.getSymbol(_selectedTarget!) ?? "" : "";

    final double resultValue = source * rate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "${Utils.formatSmartDouble(source)} $sourceSymbol to $targetSymbol",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "${Utils.formatSmartDouble(resultValue)} $targetSymbol",
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        Text(
          "1 $targetSymbol = ${Utils.formatSmartDouble(rate)} $sourceSymbol",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        Text(
          "1 $sourceSymbol = ${Utils.formatSmartDouble(reversedRate)} $targetSymbol",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
      ],
    );
  }

  void _onRatesUpdated() {
    _getRate();
  }

  Future<void> _getRate() async {
    try {
      final int source = _selectedSource ?? 0;
      final int target = _selectedTarget ?? 0;

      if (source == 0 || target == 0) {
        return;
      }

      final rate = await _ratesController.getStoredRate(source, target);
      if (rate == -9999) {
        _ratesController.addQueue(source, target);
        _temporaryRates.add((source, target));

        return;
      }
      if (mounted) {
        setState(() {
          _rate = rate;
          _reversedRate = 1 / rate;
        });
      }
    } catch (e) {
      // Do something to process the error message?
    }
  }

  Future<void> _cleanTemporaryRates() async {
    for (final (source, target) in _temporaryRates) {
      await _ratesController.delete(source, target);
      await _ratesController.delete(target, source);
    }
    _temporaryRates.clear();
  }
}

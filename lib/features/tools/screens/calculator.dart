import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../core/math.dart';

import '../../../mixins/rateable.dart';
import '../../../mixins/state.dart';

import '../../../widgets/text/balance.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/header.dart';
import '../../../widgets/numbers/flow.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/notify.dart';

import '../../cryptos/controller.dart';

class ToolsCalculatorView extends StatefulWidget {
  const ToolsCalculatorView({super.key});

  @override
  State<ToolsCalculatorView> createState() => _ToolsCalculatorViewState();
}

class _ToolsCalculatorViewState extends State<ToolsCalculatorView> with MixinsRateable<ToolsCalculatorView>, MixinsState {
  late GlobalKey<FormState> _formKey;

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
    _formKey = GlobalKey<FormState>();
    _cryptosController = CoreLocator.getit<CryptosController>();
    _sourceAmount = states.get('tool-calculator-source-amount') as String?;
    _ratesRevertAmount = states.get('tool-calculator-buyback-rate') as String?;

    _rateController = TextEditingController();
    _rateRevertController = TextEditingController();

    _rateController.text = states.get('tool-calculator-sell-rate', defaultValue: '') as String;
    _rateRevertController.text = states.get('tool-calculator-buyback-rate', defaultValue: '') as String;
    rateableAmount = _rateController.text.isEmpty ? null : _rateController.text;
    rateableSource = states.get('tool-calculator-source-crypto') as int?;
    rateableTarget = states.get('tool-calculator-target-crypto') as int?;
    _isReversed = states.get('tool-calculator-is-reversed', defaultValue: false) == true;
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
    return Form(
      key: _formKey,
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

                    SizedBox(width: 5),

                    Expanded(
                      child: WidgetsHeader(subtitle: " ", subtitleFontSize: 13, spacing: 10, child: _buildSourceCryptoField()),
                    ),

                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 38), child: Icon(Icons.arrow_forward, size: 24)),

                    Expanded(
                      child: WidgetsHeader(subtitle: "To:", subtitleFontSize: 13, spacing: 10, child: _buildResultCryptoField()),
                    ),

                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 38), child: Icon(Icons.clear, size: 24)),

                    Expanded(
                      child: WidgetsHeader(subtitle: "Sell Rate:", subtitleFontSize: 13, spacing: 10, child: _buildRatesAmountField()),
                    ),

                    Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 38), child: Icon(Icons.swap_horiz, size: 24)),

                    Expanded(
                      child: WidgetsHeader(
                        subtitle: "Buyback Rate:",
                        subtitleFontSize: 13,
                        spacing: 10,
                        child: _buildRatesRevertAmountField(),
                      ),
                    ),
                  ],
                ),

                _buildResetButton(),

                SizedBox(height: 50),

                _buildCalculatedResult(),

                SizedBox(height: 28),
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

                WidgetsHeader(title: "Sell Rate:", spacing: 10, child: _buildRatesAmountField()),

                WidgetsHeader(title: "Buyback Rate:", spacing: 10, child: _buildRatesRevertAmountField()),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildResetButton()]),

                SizedBox(height: 50),

                _buildCalculatedResult(mini: true),

                SizedBox(height: 28),
              ],
            );
          }
        },
      ),
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
        states.set('tool-calculator-buyback-rate', value);
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        if (_ratesRevertAmount != value) {
          _debounce = Timer(Duration(milliseconds: 100), () {
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

          states.set('tool-calculator-is-reversed', _isReversed);
          states.set('tool-calculator-buyback-rate', _ratesRevertAmount);
          states.set('tool-calculator-sell-rate', _rateController.text);
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
        states.set('tool-calculator-sell-rate', value);

        if (_debounce?.isActive ?? false) _debounce!.cancel();

        if (rateableAmount != value) {
          _debounce = Timer(Duration(milliseconds: 100), () {
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

          states.set('tool-calculator-is-reversed', _isReversed);
          states.set('tool-calculator-sell-rate', rateableAmount);
          states.set('tool-calculator-buyback-rate', _rateRevertController.text);
        });
      },
    );
  }

  Widget _buildSourceAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 1.5',
      initialValue: states.get('tool-calculator-source-amount') as String?,
      onChanged: (value) {
        states.set('tool-calculator-source-amount', value);
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(Duration(milliseconds: 100), () {
          setState(() {
            _sourceAmount = value;
          });
        });
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: rateableSource,
      onSelected: (id) => setState(() {
        rateableSource = id > 0 ? id : null;
        states.set('tool-calculator-source-crypto', rateableSource);
      }),
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: rateableTarget,
      onSelected: (id) => setState(() {
        rateableTarget = id > 0 ? id : null;
        states.set('tool-calculator-target-crypto', rateableTarget);
      }),
    );
  }

  Widget _buildResetButton() {
    if ((states.get('tool-calculator-source-amount') as String?)?.isNotEmpty != true &&
        (states.get('tool-calculator-source-crypto') as int?) == null &&
        (states.get('tool-calculator-target-crypto') as int?) == null &&
        (states.get('tool-calculator-sell-rate') as String?)?.isNotEmpty != true &&
        (states.get('tool-calculator-buyback-rate') as String?)?.isNotEmpty != true &&
        states.get('tool-calculator-is-reversed', defaultValue: false) != true) {
      return const SizedBox.shrink();
    }

    return WidgetsButtonsAction(
      label: 'Reset',
      icon: Icons.restart_alt,
      iconSize: 22,
      minimumSize: const Size(88, 44),
      onPressed: _resetCalculator,
    );
  }

  void _resetCalculator(WidgetsButtonsActionState s) {
    _debounce?.cancel();
    _sourceAmount = null;
    _ratesRevertAmount = null;
    rateableSource = null;
    rateableTarget = null;
    rateableAmount = null;
    rateableValue = null;
    rateableStateUpdater = null;
    _isReversed = false;
    states.remove('tool-calculator-source-amount');
    states.remove('tool-calculator-source-crypto');
    states.remove('tool-calculator-target-crypto');
    states.remove('tool-calculator-sell-rate');
    states.remove('tool-calculator-buyback-rate');
    states.remove('tool-calculator-is-reversed');
    _formKey.currentState?.reset();
    _formKey = GlobalKey<FormState>();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Widget _buildCalculatedResult({bool mini = false}) {
    final Decimal source = _sourceAmount == null ? Decimal.zero : Decimal.tryParse(Utils.sanitizeNumber(_sourceAmount!)) ?? Decimal.zero;
    final String sourceSymbol = rateableSource != null ? _cryptosController.getSymbol(rateableSource!) ?? "" : "";
    final String targetSymbol = rateableTarget != null ? _cryptosController.getSymbol(rateableTarget!) ?? "" : "";

    final Decimal entryRate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
    final Decimal returnRate = _ratesRevertAmount == null
        ? Decimal.zero
        : rateableParseToDecimal(_ratesRevertAmount!, reverse: _isReversed);

    if (source <= Decimal.zero ||
        entryRate <= Decimal.zero ||
        targetSymbol == "UNK" ||
        sourceSymbol == "UNK" ||
        targetSymbol == "" ||
        sourceSymbol == "") {
      return Text("");
    }

    final Decimal stage1Balance = source * entryRate;
    Decimal resultValue = stage1Balance;
    Decimal profit = Decimal.zero;

    if (returnRate > Decimal.zero) {
      resultValue = Math.divide(stage1Balance, returnRate);
      profit = resultValue - source;
    }

    final String currentSymbol = (returnRate > Decimal.zero) ? sourceSymbol : targetSymbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              returnRate > Decimal.zero ? "Returned Amount" : "Calculated Amount",
              style: TextStyle(fontSize: mini ? 13 : 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
            ),
            SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.copy),
              iconSize: 16,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              mouseCursor: SystemMouseCursors.click,
              tooltip: 'Copy calculation summary',
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.hovered) ? AppTheme.action : AppTheme.textMuted;
                }),
                padding: WidgetStateProperty.all(EdgeInsets.only(left: 3, right: 3, top: 5, bottom: 5)),
                minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _copyCalculatedResult(
                source: source,
                sourceSymbol: sourceSymbol,
                targetSymbol: targetSymbol,
                sellRate: entryRate,
                soldAmount: stage1Balance,
                buybackRate: returnRate,
                returnedAmount: resultValue,
                profit: profit,
                hasBuyback: returnRate > Decimal.zero,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        WidgetsNumbersFlow(
          begin: "",
          end: Utils.formatSmartDecimal(resultValue),
          suffix: " $currentSymbol",
          style: TextStyle(fontSize: mini ? 28 : 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),

        if (returnRate > Decimal.zero && profit != Decimal.zero) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.tableRowBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppTheme.separator),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                Text(
                  "Net Profit/Loss:",
                  style: TextStyle(fontSize: mini ? 12 : 14, color: AppTheme.textMuted),
                ),
                SizedBox(width: 8),
                WidgetsTextBalance(
                  text: "${Utils.formatSmartDecimal(profit)} $sourceSymbol",
                  value: resultValue.toDouble(),
                  comparator: source.toDouble(),
                  fontSize: mini ? 14 : 18,
                  fontWeight: FontWeight.w600,
                  hidePrefix: profit < Decimal.zero,
                  animated: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copyCalculatedResult({
    required Decimal source,
    required String sourceSymbol,
    required String targetSymbol,
    required Decimal sellRate,
    required Decimal soldAmount,
    required Decimal buybackRate,
    required Decimal returnedAmount,
    required Decimal profit,
    required bool hasBuyback,
  }) async {
    final sourceText = Utils.formatSmartDecimal(source);
    final sellRateText = Utils.formatSmartDecimal(sellRate);
    final soldAmountText = Utils.formatSmartDecimal(soldAmount);
    final buybackRateText = Utils.formatSmartDecimal(buybackRate);
    final returnedAmountText = Utils.formatSmartDecimal(returnedAmount);
    final profitText = Utils.formatSmartDecimal(profit.abs());

    final String summary = hasBuyback
        ? 'Converted $sourceText $sourceSymbol to $soldAmountText $targetSymbol at a sell rate of $sellRateText $targetSymbol per $sourceSymbol. '
              'At a buyback rate of $buybackRateText $targetSymbol per $sourceSymbol, $returnedAmountText $sourceSymbol was returned, '
              'resulting in a net ${profit > Decimal.zero
                  ? 'profit'
                  : profit < Decimal.zero
                  ? 'loss'
                  : 'break-even'}'
              '${profit == Decimal.zero ? '' : ' of $profitText $sourceSymbol'}.'
        : 'Converted $sourceText $sourceSymbol to $soldAmountText $targetSymbol at a sell rate of $sellRateText $targetSymbol per $sourceSymbol.';

    await Clipboard.setData(ClipboardData(text: summary));
    widgetsNotifySuccess('Calculation summary copied to clipboard.');
  }
}

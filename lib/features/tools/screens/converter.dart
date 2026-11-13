import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/state.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/fields/amount.dart';
import '../../../app/theme.dart';
import '../../../core/utils.dart';
import '../../../widgets/header.dart';
import '../../../widgets/numbers/flow.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/text/selectable.dart';
import '../../../widgets/notify.dart';
import '../../cryptos/controller.dart';

class ToolsConverterView extends StatefulWidget {
  const ToolsConverterView({super.key});

  @override
  State<ToolsConverterView> createState() => _ToolsConverterViewState();
}

class _ToolsConverterViewState extends State<ToolsConverterView> with MixinsRateable<ToolsConverterView>, MixinsState {
  late GlobalKey<FormState> _formKey;

  late final CryptosController _cryptosController;

  String? _sourceAmount;
  Decimal? _reversedRate;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _cryptosController = CoreLocator.getit<CryptosController>();
    _sourceAmount = states.get('tool-converter-source-amount') as String?;
    _reversedRate = null;

    rateableWithField = false;
    rateableSource = states.get('tool-converter-source-crypto') as int?;
    rateableTarget = states.get('tool-converter-target-crypto') as int?;
    if (rateableSource != null && rateableTarget != null) {
      rateableGetRate(refresh: false, silent: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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

                    SizedBox(width: 4),

                    WidgetsHeader(
                      subtitle: " ",
                      subtitleFontSize: 13,
                      spacing: 10,
                      child: WidgetsButtonsAction(
                        icon: Icons.swap_horiz,
                        tooltip: "Convert",
                        padding: EdgeInsets.all(0),
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

                _buildResetButton(),

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

  Widget _buildSourceAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 1.5',
      initialValue: states.get('tool-converter-source-amount') as String?,
      onChanged: (value) {
        _sourceAmount = value;
        states.set('tool-converter-source-amount', value);
        if (rateableSource != null && rateableTarget != null) {
          rateableGetRate();
        }
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: rateableSource,
      onSelected: (id) => setState(() {
        final int? source = id > 0 ? id : null;

        if (source != rateableSource) {
          rateableValue = null;
          _reversedRate = null;
        }

        rateableSource = source;
        states.set('tool-converter-source-crypto', rateableSource);

        if (rateableSource != null && rateableTarget != null) {
          rateableGetRate(refresh: false, silent: true);
        }
      }),
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: rateableTarget,
      onSelected: (id) => setState(() {
        final int? target = id > 0 ? id : null;

        if (target != rateableTarget) {
          rateableValue = null;
          _reversedRate = null;
        }

        rateableTarget = target;
        states.set('tool-converter-target-crypto', rateableTarget);

        if (rateableSource != null && rateableTarget != null) {
          rateableGetRate(refresh: false, silent: true);
        }
      }),
    );
  }

  Widget _buildResetButton() {
    if ((states.get('tool-converter-source-amount') as String?)?.isNotEmpty != true &&
        (states.get('tool-converter-source-crypto') as int?) == null &&
        (states.get('tool-converter-target-crypto') as int?) == null) {
      return const SizedBox.shrink();
    }

    return WidgetsButtonsAction(
      label: 'Reset',
      icon: Icons.restart_alt,
      iconSize: 22,
      minimumSize: const Size(88, 44),
      onPressed: _resetConverter,
    );
  }

  void _resetConverter(WidgetsButtonsActionState state) {
    _debounce?.cancel();
    _sourceAmount = null;
    _reversedRate = null;
    rateableSource = null;
    rateableTarget = null;
    rateableValue = null;
    rateableAmount = null;
    states.remove('tool-converter-source-amount');
    states.remove('tool-converter-source-crypto');
    states.remove('tool-converter-target-crypto');
    _formKey.currentState?.reset();
    _formKey = GlobalKey<FormState>();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
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
      return Text("");
    }

    final Decimal resultValue = source * rate;
    final Decimal reverseRate = _reversedRate!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WidgetsTextSelectable(
              "${Utils.formatSmartDecimal(source)} $sourceSymbol to $targetSymbol",
              style: TextStyle(fontSize: mini ? 13 : 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
            ),
            IconButton(
              icon: Icon(Icons.copy),
              iconSize: 16,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              mouseCursor: SystemMouseCursors.click,
              tooltip: 'Copy conversion summary',
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.hovered) ? AppTheme.action : AppTheme.textMuted;
                }),
                padding: WidgetStateProperty.all(EdgeInsets.only(left: 3, right: 3, top: 5, bottom: 5)),
                minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _copyConversionSummary(
                source: source,
                sourceSymbol: sourceSymbol,
                targetSymbol: targetSymbol,
                rate: rate,
                reverseRate: reverseRate,
                result: resultValue,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        WidgetsNumbersFlow(
          begin: "",
          end: Utils.formatSmartDecimal(resultValue),
          suffix: " $targetSymbol",
          style: TextStyle(fontSize: mini ? 28 : 42, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),

        WidgetsTextSelectable(
          "1 $targetSymbol = ${Utils.formatSmartDecimal(rate)} $sourceSymbol",
          style: TextStyle(fontSize: mini ? 12 : 14, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        WidgetsTextSelectable(
          "1 $sourceSymbol = ${Utils.formatSmartDecimal(reverseRate)} $targetSymbol",
          style: TextStyle(fontSize: mini ? 11 : 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Future<void> _copyConversionSummary({
    required Decimal source,
    required String sourceSymbol,
    required String targetSymbol,
    required Decimal rate,
    required Decimal reverseRate,
    required Decimal result,
  }) async {
    final summary =
        'Converted ${Utils.formatSmartDecimal(source)} $sourceSymbol to '
        '${Utils.formatSmartDecimal(result)} $targetSymbol at a rate of '
        '${Utils.formatSmartDecimal(rate)} $targetSymbol per $sourceSymbol '
        '(reverse rate: ${Utils.formatSmartDecimal(reverseRate)} $sourceSymbol per $targetSymbol).';

    await Clipboard.setData(ClipboardData(text: summary));
    widgetsNotifySuccess('Conversion summary copied to clipboard.');
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    if (rateableValue != null && rateableValue! > Decimal.zero) {
      _reversedRate = Math.divide(Decimal.one, rateableValue!);
    }
  }
}

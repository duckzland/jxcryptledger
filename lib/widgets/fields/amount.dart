import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/math.dart';
import '../../mixins/suffix.dart';
import '../context_menu.dart';
import '../notify.dart';
import '../../core/utils.dart';

class WidgetsFieldsAmount extends StatefulWidget {
  final String title;
  final String helperText;
  final String? initialValue;
  final String? suffixText;
  final bool enabled;
  final bool allowNegative;
  final bool allowClean;
  final bool allowCopy;
  final bool allowReverse;
  final bool allowRate;
  final Decimal? useMax;
  final bool disposeController;

  final TextEditingController? controller;

  final void Function(String value)? onChanged;
  final void Function(void Function(String value, String helperText))? onRetrievingRate;
  final void Function()? onReversing;

  const WidgetsFieldsAmount({
    super.key,
    required this.title,
    required this.helperText,
    this.controller,
    this.suffixText,
    this.initialValue,
    this.enabled = true,
    this.allowNegative = false,
    this.allowClean = true,
    this.allowCopy = true,
    this.allowReverse = false,
    this.allowRate = false,
    this.disposeController = true,
    this.useMax,
    this.onChanged,
    this.onRetrievingRate,
    this.onReversing,
  });

  @override
  State<WidgetsFieldsAmount> createState() => _WidgetsFieldsAmountState();
}

class _WidgetsFieldsAmountState extends State<WidgetsFieldsAmount> with MixinsSuffix<WidgetsFieldsAmount> {
  late final TextEditingController _controller;
  Timer? _debounce;

  String _helperText = "";

  bool get _shouldShowSuffix =>
      widget.suffixText != null ||
      widget.enabled && (widget.useMax != null || widget.allowClean || widget.allowCopy || widget.allowReverse || widget.allowRate);

  @override
  String get suffixText => widget.suffixText ?? "";

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null) {
      final val = widget.initialValue!;
      _controller.text = val.isEmpty ? val : Utils.formatSmartDecimal(Utils.parseDecimal(val), smartDecimal: false, maxDecimals: 18);
    }

    _helperText = widget.helperText;
  }

  @override
  void dispose() {
    _debounce?.cancel();

    // Only dispose own controller!
    if (widget.disposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void suffixOnUseMax() {
    final String maxValue = Utils.formatSmartDecimal(
      widget.useMax ?? Decimal.zero,
      smartDecimal: false,
      maxDecimals: 18,
    ).replaceAll(",", "");

    _controller.text = maxValue;
    widget.onChanged?.call(maxValue);
    setState(() {});
  }

  @override
  void suffixOnClean() {
    _controller.text = "";
    widget.onChanged?.call("");
    setState(() {});
  }

  @override
  void suffixOnCopy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    widgetsNotifySuccess("${_controller.text} copied to clipboard");
  }

  @override
  void suffixOnReverse() {
    try {
      final parsed = Utils.parseDecimal(_controller.text);
      final reversed = Math.divide(Decimal.one, parsed);
      _controller.text = Utils.formatSmartDecimal(reversed, smartDecimal: false, maxDecimals: 18).replaceAll(",", "");
      widget.onChanged?.call(reversed.toString());
      widget.onReversing?.call();
      setState(() {});
    } catch (e) {
      widgetsNotifyError('Failed to reverse "${_controller.text}"');
    }
  }

  @override
  void suffixOnRate() {
    widget.onRetrievingRate?.call(updateState);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      contextMenuBuilder: (context, editableTextState) {
        return WidgetsContextMenu(
          anchor: editableTextState.contextMenuAnchors.primaryAnchor,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.title,
        hintText: _helperText,
        enabled: widget.enabled,
        suffixIcon: _shouldShowSuffix
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.suffixText != null) suffixIconText(),

                  if (widget.useMax != null) suffixIconUseMax('Use maximum amount'),

                  if (widget.allowRate) suffixIconRate('Retrieve current rate'),

                  if (widget.allowReverse && _controller.text != "") suffixIconReverse('Reverse amount'),

                  if (widget.allowCopy && _controller.text != "") suffixIconCopy('Copy to clipboard'),

                  if (widget.allowClean && _controller.text != "") suffixIconClean('Reset amount'),

                  SizedBox(width: 6),
                ],
              )
            : null,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
      enabled: widget.enabled,
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(Duration(milliseconds: 100), () {
          widget.onChanged?.call(value);
          setState(() {});
        });
      },
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }

    final invalidChars = RegExp(r'[^0-9\+\-\,\.]');
    if (invalidChars.hasMatch(value)) {
      return 'Enter a valid number';
    }

    final parsed = Utils.parseDecimal(value);

    if (parsed == Decimal.zero && value.trim().isNotEmpty && value.trim() != '0' && value.trim() != '+0' && value.trim() != '-0') {
      return 'Enter a valid number';
    }

    if (!widget.allowNegative && parsed < Decimal.zero) {
      return 'Negative not allowed';
    }

    if (parsed == Decimal.zero) {
      return 'Amount must not be zero';
    }

    if (widget.useMax != null) {
      final max = widget.useMax!;
      if (parsed > max) {
        return 'Amount cannot exceed $max';
      }
    }

    return null;
  }

  void updateState(String value, String helperText) {
    if (value != _controller.text || helperText != _helperText) {
      _controller.text = value;
      _helperText = helperText;
      setState(() {});
    }
  }
}

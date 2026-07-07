import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/math.dart';
import '../../mixins/suffix.dart';
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
  final double? useMax;

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
      _controller.text = val == "" ? val : Utils.formatSmartDouble(double.parse(val));
    }

    _helperText = widget.helperText;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void suffixOnUseMax() {
    final String maxValue = Utils.formatSmartDouble(widget.useMax!).replaceAll(",", "");

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
      final sanitized = Utils.sanitizeNumber(_controller.text);
      final parsed = double.parse(sanitized);
      final reversed = Math.divide(1, parsed);
      _controller.text = Utils.formatSmartDouble(reversed).replaceAll(",", "");
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

                  const SizedBox(width: 6),
                ],
              )
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
      enabled: widget.enabled,
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 100), () {
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

    final sanitized = Utils.sanitizeNumber(value);
    final parsed = double.tryParse(sanitized);

    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (!widget.allowNegative && parsed < 0) {
      return 'Negative amounts are not allowed';
    }

    if (parsed == 0) {
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

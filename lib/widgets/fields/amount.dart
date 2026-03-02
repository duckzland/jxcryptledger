import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jxcryptledger/widgets/notify.dart';

import '../../app/theme.dart';
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
  final double? useMax;

  final void Function(String value)? onChanged;

  const WidgetsFieldsAmount({
    super.key,
    required this.title,
    required this.helperText,
    this.suffixText,
    this.initialValue,
    this.enabled = true,
    this.allowNegative = false,
    this.allowClean = true,
    this.allowCopy = true,
    this.useMax,
    this.onChanged,
  });

  @override
  State<WidgetsFieldsAmount> createState() => _WidgetsFieldsAmountState();
}

class _WidgetsFieldsAmountState extends State<WidgetsFieldsAmount> {
  final TextEditingController _amountController = TextEditingController();
  Timer? _debounce;

  bool get _shouldShowSuffix =>
      widget.suffixText != null || widget.enabled && (widget.useMax != null || widget.allowClean || widget.allowCopy);

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _amountController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: widget.title,
        hintText: widget.helperText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabled: widget.enabled,
        suffixIcon: _shouldShowSuffix
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.suffixText != null) Text("${widget.suffixText!} ", style: TextStyle(color: AppTheme.textMuted)),

                  if (widget.useMax != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_up),
                      iconSize: 16,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      mouseCursor: SystemMouseCursors.click,
                      tooltip: 'Use maximum amount',
                      style: ButtonStyle(
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppTheme.action;
                          }
                          return AppTheme.textMuted;
                        }),
                        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
                        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final String maxValue = Utils.formatSmartDouble(widget.useMax!).replaceAll(",", "");

                        _amountController.text = maxValue;
                        widget.onChanged?.call(maxValue);
                        setState(() {});
                      },
                    ),

                  if (widget.allowCopy && _amountController.text != "")
                    IconButton(
                      icon: const Icon(Icons.copy),
                      iconSize: 16,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      mouseCursor: SystemMouseCursors.click,
                      tooltip: 'Copy to clipboard',
                      style: ButtonStyle(
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppTheme.action;
                          }
                          return AppTheme.textMuted;
                        }),
                        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
                        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _amountController.text));
                        widgetsNotifySuccess("${_amountController.text} copied to clipboard");
                      },
                    ),

                  if (widget.allowClean && _amountController.text != "")
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 16,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      mouseCursor: SystemMouseCursors.click,
                      tooltip: 'Reset amount',
                      style: ButtonStyle(
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppTheme.error;
                          }
                          return AppTheme.textMuted;
                        }),
                        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
                        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _amountController.text = "";
                        widget.onChanged?.call("");
                        setState(() {});
                      },
                    ),

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
}

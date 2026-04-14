import 'dart:async';
import 'package:flutter/material.dart';

class WidgetsFieldsTextarea extends StatefulWidget {
  final String title;
  final String helperText;
  final String? initialValue;
  final bool enabled;
  final void Function(String value)? onChanged;

  const WidgetsFieldsTextarea({
    super.key,
    required this.title,
    required this.helperText,
    this.initialValue,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<WidgetsFieldsTextarea> createState() => _WidgetsFieldsTextareaState();
}

class _WidgetsFieldsTextareaState extends State<WidgetsFieldsTextarea> {
  final TextEditingController _textareaController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _textareaController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textareaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _textareaController,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        labelText: widget.title,
        hintText: widget.helperText,
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 100), () {
          widget.onChanged?.call(value);
          setState(() {});
        });
      },
    );
  }
}

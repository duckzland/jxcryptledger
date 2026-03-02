import 'package:flutter/material.dart';

import '../../app/theme.dart';

class WidgetsFieldsDatepicker extends StatefulWidget {
  final String labelText;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool enabled;

  final ValueChanged<DateTime> onSelected;

  const WidgetsFieldsDatepicker({
    super.key,
    required this.labelText,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  State<WidgetsFieldsDatepicker> createState() => _WidgetsFieldsDatepickerState();
}

class _WidgetsFieldsDatepickerState extends State<WidgetsFieldsDatepicker> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: widget.enabled,
      decoration: InputDecoration(labelText: widget.labelText),
      controller: TextEditingController(
        text: _selectedDate != null
            ? "${_selectedDate!.day.toString().padLeft(2, '0')}/"
                  "${_selectedDate!.month.toString().padLeft(2, '0')}/"
                  "${_selectedDate!.year}"
            : "",
      ),
      onTap: () async {
        if (!widget.enabled) {
          return;
        }

        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? widget.initialDate,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          widget.onSelected(picked);
        }
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../context_menu.dart';

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
      contextMenuBuilder: (context, editableTextState) {
        return WidgetsContextMenu(
          anchor: editableTextState.contextMenuAnchors.primaryAnchor,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
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

          // Until Flutter give sane way to style the contextMenu, just use the calendar only mode.
          initialEntryMode: DatePickerEntryMode.calendarOnly,
        );

        if (picked != null) {
          setState(() => _selectedDate = picked);
          widget.onSelected(picked);
        }
      },
    );
  }
}

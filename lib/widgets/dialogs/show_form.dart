import 'package:flutter/material.dart';
import '../button.dart';

class WidgetsDialogsShowForm extends StatefulWidget {
  final Widget Function(BuildContext dialogContext) buildForm;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonState s)? evaluator;
  final bool persistBg;

  const WidgetsDialogsShowForm({
    super.key,
    required this.buildForm,

    this.label,
    this.tooltip = "Add new item",
    this.icon = Icons.add,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.action,
    this.evaluator,
    this.persistBg = false,
  });

  @override
  State<WidgetsDialogsShowForm> createState() => _WidgetsDialogsShowFormState();
}

class _WidgetsDialogsShowFormState extends State<WidgetsDialogsShowForm> {
  Future<void> _showDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: widget.buildForm(dialogContext)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsButton(
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      onPressed: (_) => _showDialog(context),
      evaluator: widget.evaluator,
      persistBg: widget.persistBg,
    );
  }
}

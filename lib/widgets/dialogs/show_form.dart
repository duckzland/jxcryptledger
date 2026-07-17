import 'package:flutter/material.dart';
import '../buttons/action.dart';

class WidgetsDialogsShowForm extends StatefulWidget {
  final Widget Function(BuildContext dialogContext) buildForm;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final double radius;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonsActionState s)? evaluator;
  final bool filledMode;
  final bool ghostMode;
  final bool plainMode;
  final bool centerMode;

  final Listenable? listener;

  const WidgetsDialogsShowForm({
    super.key,
    required this.buildForm,

    this.label,
    this.tooltip = "Add new item",
    this.icon = Icons.add,
    this.iconSize = 20,
    this.radius = 6.0,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.action,
    this.evaluator,
    this.filledMode = false,
    this.ghostMode = false,
    this.plainMode = false,
    this.centerMode = true,
    this.listener,
  });

  @override
  State<WidgetsDialogsShowForm> createState() => _WidgetsDialogsShowFormState();

  WidgetsDialogsShowForm copyWith({
    Widget Function(BuildContext dialogContext)? buildForm,
    String? label,
    String? tooltip,
    IconData? icon,
    double? iconSize,
    double? radius,
    EdgeInsets? padding,
    Size? minimumSize,
    WidgetsButtonActionState? initialState,
    void Function(WidgetsButtonsActionState s)? evaluator,
    bool? filledMode,
    bool? ghostMode,
    bool? plainMode,
    bool? centerMode,
    Listenable? listener,
  }) {
    return WidgetsDialogsShowForm(
      buildForm: buildForm ?? this.buildForm,
      label: label ?? this.label,
      tooltip: tooltip ?? this.tooltip,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      initialState: initialState ?? this.initialState,
      evaluator: evaluator ?? this.evaluator,
      filledMode: filledMode ?? this.filledMode,
      ghostMode: ghostMode ?? this.ghostMode,
      plainMode: plainMode ?? this.plainMode,
      centerMode: centerMode ?? this.centerMode,
      listener: listener ?? this.listener,
    );
  }
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
    return WidgetsButtonsAction(
      label: widget.label,
      tooltip: widget.plainMode ? null : widget.tooltip,
      icon: widget.plainMode ? null : widget.icon,
      iconSize: widget.iconSize,
      radius: widget.plainMode ? 0.0 : widget.radius,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.plainMode ? WidgetsButtonActionState.normal : widget.initialState,
      onPressed: (_) => _showDialog(context),
      evaluator: widget.evaluator,
      filledMode: widget.plainMode ? false : widget.filledMode,
      ghostMode: widget.plainMode ? true : widget.ghostMode,
      centerMode: widget.plainMode ? false : widget.centerMode,
      listener: widget.listener,
    );
  }
}

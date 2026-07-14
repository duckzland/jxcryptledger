import 'package:flutter/material.dart';
import '../buttons/action.dart';

class WidgetsDialogsShowForm extends StatefulWidget {
  final Widget Function(BuildContext dialogContext) buildForm;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonsActionState s)? evaluator;
  final bool persistBg;
  final bool initialTransparent;
  final bool centered;
  final Listenable? listener;

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
    this.initialTransparent = false,
    this.centered = true,
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
    EdgeInsets? padding,
    Size? minimumSize,
    WidgetsButtonActionState? initialState,
    void Function(WidgetsButtonsActionState s)? evaluator,
    bool? persistBg,
    bool? initialTransparent,
    bool? centered,
    Listenable? listener,
  }) {
    return WidgetsDialogsShowForm(
      buildForm: buildForm ?? this.buildForm,
      label: label ?? this.label,
      tooltip: tooltip ?? this.tooltip,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      initialState: initialState ?? this.initialState,
      evaluator: evaluator ?? this.evaluator,
      persistBg: persistBg ?? this.persistBg,
      initialTransparent: initialTransparent ?? this.initialTransparent,
      centered: centered ?? this.centered,
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
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      onPressed: (_) => _showDialog(context),
      evaluator: widget.evaluator,
      persistBg: widget.persistBg,
      initialTransparent: widget.initialTransparent,
      centered: widget.centered,
      listener: widget.listener,
    );
  }
}

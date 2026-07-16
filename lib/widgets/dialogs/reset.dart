import 'package:flutter/material.dart';
import '../buttons/action.dart';
import 'alert.dart';

class WidgetsDialogsReset extends StatefulWidget {
  final Future<void> Function() onWipe;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final double radius;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonsActionState s)? evaluator;
  final bool Function()? isEmpty;
  final bool filledMode;
  final bool ghostMode;
  final bool plainMode;
  final bool centerMode;
  
  final Listenable? listener;

  final String dialogTitle;
  final String dialogMessage;
  final String dialogCancelLabel;
  final String dialogWipeLabel;

  const WidgetsDialogsReset({
    super.key,
    required this.onWipe,

    this.label,
    this.tooltip = "Reset database",
    this.icon = Icons.delete_sweep,
    this.iconSize = 20,
    this.radius = 6.0,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.error,
    this.plainMode = false,
    this.evaluator,
    this.isEmpty,
    this.filledMode = false,
    this.ghostMode = false,
    this.centerMode = true,
    this.listener,

    this.dialogTitle = "Reset Database",
    this.dialogMessage =
        "Are you sure you want to reset the database?\n"
        "This will remove all entries and create an empty database.\n"
        "This action cannot be undone.",
    this.dialogCancelLabel = "Cancel",
    this.dialogWipeLabel = "Reset",
  });

  @override
  State<WidgetsDialogsReset> createState() => _WidgetsDialogsResetState();

  WidgetsDialogsReset copyWith({
    String? label,
    String? tooltip,
    IconData? icon,
    double? iconSize,
    double? radius,
    EdgeInsets? padding,
    Size? minimumSize,
    WidgetsButtonActionState? initialState,
    void Function(WidgetsButtonsActionState s)? evaluator,
    bool? persistBg,
    bool? initialTransparent,
    bool? insideDropdown,
    bool? centered,
    Listenable? listener,
    String? dialogTitle,
    String? dialogMessage,
    String? dialogCancelLabel,
    String? dialogWipeLabel,
    Future<void> Function()? onWipe,
  }) {
    return WidgetsDialogsReset(
      label: label ?? this.label,
      tooltip: tooltip ?? this.tooltip,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      initialState: initialState ?? this.initialState,
      evaluator: evaluator ?? this.evaluator,
      filledMode: persistBg ?? this.filledMode,
      ghostMode: initialTransparent ?? this.ghostMode,
      plainMode: insideDropdown ?? this.plainMode,
      centerMode: centered ?? this.centerMode,
      listener: listener ?? this.listener,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogMessage: dialogMessage ?? this.dialogMessage,
      dialogCancelLabel: dialogCancelLabel ?? this.dialogCancelLabel,
      dialogWipeLabel: dialogWipeLabel ?? this.dialogWipeLabel,
      onWipe: onWipe ?? this.onWipe,
    );
  }
}

class _WidgetsDialogsResetState extends State<WidgetsDialogsReset> {
  void _evaluate(WidgetsButtonsActionState s) {
    if (widget.isEmpty == null) {
      return;
    }

    if (widget.isEmpty!()) {
      s.disable();
    } else {
      s.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    void Function(WidgetsButtonsActionState s)? evaluator = widget.evaluator;
    if (evaluator == null && widget.isEmpty != null) {
      evaluator = _evaluate;
    }

    return WidgetsDialogsAlert(
      dialogTitle: widget.dialogTitle,
      dialogMessage: widget.dialogMessage,
      dialogCancelLabel: widget.dialogCancelLabel,
      dialogConfirmLabel: widget.dialogWipeLabel,
      actionStartCallback: widget.onWipe,
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      radius: widget.radius,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      evaluator: evaluator,
      filledMode: widget.filledMode,
      ghostMode: widget.ghostMode,
      plainMode: widget.plainMode,
      centerMode: widget.centerMode,
      listener: widget.listener,
    );
  }
}

import 'package:flutter/material.dart';
import '../../mixins/actionable.dart';
import '../buttons/action.dart';

class WidgetsDialogsAlert<T> extends StatefulWidget with MixinsActionable {
  final String? label;
  final String tooltip;
  final IconData? icon;
  final double iconSize;
  final double radius;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonsActionState s)? evaluator;
  final bool persistBg;
  final bool showMessage;
  final bool initialTransparent;
  final bool centered;
  final Listenable? listener;

  final String dialogTitle;
  final String dialogMessage;
  final String dialogCancelLabel;
  final String dialogConfirmLabel;

  final T? actionData;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;
  final Future<void> Function(T)? actionCallback;
  final VoidCallback? actionCompleteCallback;
  final VoidCallback? actionStartCallback;
  final Future<void> Function(BuildContext)? onPressed;

  const WidgetsDialogsAlert({
    super.key,

    this.label,
    this.tooltip = "Confirm action",
    this.icon,
    this.iconSize = 20,
    this.radius = 6.0,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.error,
    this.evaluator,
    this.persistBg = false,
    this.showMessage = true,
    this.initialTransparent = false,
    this.centered = true,
    this.listener,

    this.dialogTitle = "Are you sure?",
    this.dialogMessage = "This action cannot be undone.",
    this.dialogCancelLabel = "Cancel",
    this.dialogConfirmLabel = "Confirm",

    this.actionData,
    this.actionSuccessMessage,
    this.actionErrorMessage,
    this.actionCompleteCallback,
    this.actionCallback,
    this.actionStartCallback,
    this.onPressed,
  });

  @override
  State<WidgetsDialogsAlert<T>> createState() => _WidgetsDialogsAlertState<T>();

  WidgetsDialogsAlert<T> copyWith({
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
    bool? centered,
    Listenable? listener,
    bool? showMessage,
    String? dialogTitle,
    String? dialogMessage,
    String? dialogCancelLabel,
    String? dialogConfirmLabel,
    T? actionData,
    String? actionSuccessMessage,
    String? actionErrorMessage,
    Future<void> Function(T)? actionCallback,
    VoidCallback? actionCompleteCallback,
    VoidCallback? actionStartCallback,
    Future<void> Function(BuildContext)? onPressed,
  }) {
    return WidgetsDialogsAlert<T>(
      label: label ?? this.label,
      tooltip: tooltip ?? this.tooltip,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      initialState: initialState ?? this.initialState,
      evaluator: evaluator ?? this.evaluator,
      persistBg: persistBg ?? this.persistBg,
      initialTransparent: initialTransparent ?? this.initialTransparent,
      centered: centered ?? this.centered,
      listener: listener ?? this.listener,
      showMessage: showMessage ?? this.showMessage,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogMessage: dialogMessage ?? this.dialogMessage,
      dialogCancelLabel: dialogCancelLabel ?? this.dialogCancelLabel,
      dialogConfirmLabel: dialogConfirmLabel ?? this.dialogConfirmLabel,
      actionData: actionData ?? this.actionData,
      actionSuccessMessage: actionSuccessMessage ?? this.actionSuccessMessage,
      actionErrorMessage: actionErrorMessage ?? this.actionErrorMessage,
      actionCallback: actionCallback ?? this.actionCallback,
      actionCompleteCallback: actionCompleteCallback ?? this.actionCompleteCallback,
      actionStartCallback: actionStartCallback ?? this.actionStartCallback,
      onPressed: onPressed ?? this.onPressed,
    );
  }
}

class _WidgetsDialogsAlertState<T> extends State<WidgetsDialogsAlert<T>> with MixinsActionable {
  Future<void> _showDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth;
    if (screenWidth > 360) {
      dialogWidth = 300;
    } else {
      dialogWidth = screenWidth * 0.9;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: Text(widget.dialogTitle),
            content: ConstrainedBox(
              constraints: BoxConstraints(minWidth: dialogWidth),
              child: Text(widget.dialogMessage),
            ),
            actions: [
              Wrap(
                direction: Axis.horizontal,
                runSpacing: 14,
                spacing: 10,
                runAlignment: WrapAlignment.center,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WidgetsButtonsAction(label: widget.dialogCancelLabel, onPressed: (_) => Navigator.pop(dialogContext)),
                  WidgetsButtonsAction(
                    label: widget.dialogConfirmLabel,
                    initialState: widget.initialState,
                    onPressed: (_) => actionableAction<T>(
                      context,
                      dialogContext: dialogContext,
                      data: widget.actionData,
                      action: widget.actionCallback,
                      onStart: widget.actionStartCallback,
                      onComplete: widget.actionCompleteCallback,
                      successMessage: widget.actionSuccessMessage,
                      errorMessage: widget.actionErrorMessage,
                      showMessage: widget.showMessage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      radius: widget.radius,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      onPressed: (_) => widget.onPressed?.call(context) ?? _showDialog(context),
      evaluator: widget.evaluator,
      persistBg: widget.persistBg,
      initialTransparent: widget.initialTransparent,
      centered: widget.centered,
      listener: widget.listener,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum WidgetButtonActionState {
  allowActions,
  disallowActions,
  disabled,
  inProgress,
  active,
  error,
  normal,
  primary,
  action,
}

class WidgetButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final FutureOr<void> Function(WidgetButtonState state)? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final FutureOr<void> Function(WidgetButtonState state)? evaluator;
  final WidgetButtonActionState initialState;
  final double? iconSize;
  final Size? minimumSize;

  const WidgetButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.padding,
    this.evaluator,
    this.initialState = WidgetButtonActionState.normal,
    this.iconSize,
    this.minimumSize,
  });

  @override
  State<WidgetButton> createState() => WidgetButtonState();
}

class WidgetButtonState extends State<WidgetButton> {
  WidgetButtonActionState _state = WidgetButtonActionState.normal;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    // Run evaluator on init
    _runEvaluator();
  }

  Future<void> _runEvaluator() async {
    final eval = widget.evaluator;
    if (eval == null) return;
    try {
      final res = eval(this);
      await Future.value(res);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runEvaluator();
  }

  @override
  void didUpdateWidget(covariant WidgetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runEvaluator();
  }

  bool get _disabled => _state == WidgetButtonActionState.disabled || _state == WidgetButtonActionState.disallowActions;

  bool get _inProgress => _state == WidgetButtonActionState.inProgress;

  bool get _isActive => _state == WidgetButtonActionState.active;

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor();
    final fg = _foregroundColor();

    final button = MouseRegion(
      cursor: _disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(bg),
          foregroundColor: WidgetStateProperty.all(fg),
          padding: WidgetStateProperty.all(widget.padding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          elevation: WidgetStateProperty.all(2),
          minimumSize: WidgetStateProperty.all(widget.minimumSize ?? Size.zero),
          mouseCursor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click,
          ),
        ),
        onPressed: _disabled || _inProgress || _isActive
            ? null
            : () async {
                final userPressed = widget.onPressed;
                if (userPressed != null) {
                  final res = userPressed(this);
                  if (res is Future) await res;
                }
                // Re-evaluate state after an interaction
                await _runEvaluator();
              },
        child: _buildChild(fg),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }

  Widget _buildChild(Color fg) {
    if (_inProgress) {
      final size = (widget.iconSize ?? 18) - 2;
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(strokeWidth: 4, color: fg),
        ),
      );
    }

    if (widget.label != null && widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: widget.iconSize ?? 18, color: fg),
          const SizedBox(width: 8),
          Text(widget.label!),
        ],
      );
    }

    if (widget.icon != null) {
      return Icon(widget.icon, size: widget.iconSize ?? 18, color: fg);
    }

    return Text(widget.label ?? "");
  }

  Color _backgroundColor() {
    switch (_state) {
      case WidgetButtonActionState.disabled:
      case WidgetButtonActionState.disallowActions:
        return AppTheme.buttonBgDisabled;

      case WidgetButtonActionState.inProgress:
        return AppTheme.buttonBgProgress;

      case WidgetButtonActionState.active:
        return AppTheme.buttonBgActive;

      case WidgetButtonActionState.error:
        return AppTheme.buttonBgError;

      case WidgetButtonActionState.primary:
        return AppTheme.buttonBgPrimary;

      case WidgetButtonActionState.action:
        return AppTheme.buttonBgAction;

      case WidgetButtonActionState.allowActions:
      case WidgetButtonActionState.normal:
        return AppTheme.buttonBg;
    }
  }

  Color _foregroundColor() {
    switch (_state) {
      case WidgetButtonActionState.disabled:
      case WidgetButtonActionState.disallowActions:
        return AppTheme.buttonFgDisabled;

      case WidgetButtonActionState.inProgress:
        return AppTheme.buttonFgProgress;

      case WidgetButtonActionState.active:
        return AppTheme.buttonFgActive;

      case WidgetButtonActionState.primary:
        return AppTheme.buttonFgPrimary;

      case WidgetButtonActionState.action:
        return AppTheme.buttonFgAction;

      case WidgetButtonActionState.error:
        return AppTheme.buttonFgError;

      case WidgetButtonActionState.allowActions:
      case WidgetButtonActionState.normal:
        return AppTheme.buttonFg;
    }
  }

  // Helper methods previously provided by AppActionController
  WidgetButtonActionState setAppState(WidgetButtonActionState s) {
    if (mounted) setState(() => _state = s);
    return s;
  }

  WidgetButtonActionState allowActions() => setAppState(WidgetButtonActionState.allowActions);
  WidgetButtonActionState disallowActions() => setAppState(WidgetButtonActionState.disallowActions);
  WidgetButtonActionState disable() => setAppState(WidgetButtonActionState.disabled);
  WidgetButtonActionState enable() => setAppState(WidgetButtonActionState.normal);
  WidgetButtonActionState normal() => setAppState(WidgetButtonActionState.normal);
  WidgetButtonActionState primary() => setAppState(WidgetButtonActionState.primary);
  WidgetButtonActionState progress() => setAppState(WidgetButtonActionState.inProgress);
  WidgetButtonActionState active() => setAppState(WidgetButtonActionState.active);
  WidgetButtonActionState error() => setAppState(WidgetButtonActionState.error);
  WidgetButtonActionState reset() => setAppState(WidgetButtonActionState.normal);
  WidgetButtonActionState action() => setAppState(WidgetButtonActionState.action);
}

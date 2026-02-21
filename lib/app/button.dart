import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

enum AppActionState { allowActions, disallowActions, disabled, inProgress, active, error, normal }

class AppButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final FutureOr<void> Function(AppButtonState state)? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final FutureOr<void> Function(AppButtonState state)? evaluator;
  final AppActionState initialState;
  final double? iconSize;
  final Size? minimumSize;

  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.padding,
    this.evaluator,
    this.initialState = AppActionState.normal,
    this.iconSize,
    this.minimumSize,
  });

  @override
  State<AppButton> createState() => AppButtonState();
}

class AppButtonState extends State<AppButton> {
  AppActionState _state = AppActionState.normal;

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
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runEvaluator();
  }

  bool get _disabled => _state == AppActionState.disabled || _state == AppActionState.disallowActions;

  bool get _inProgress => _state == AppActionState.inProgress;

  bool get _isActive => _state == AppActionState.active;

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
      case AppActionState.disabled:
      case AppActionState.disallowActions:
        return AppTheme.buttonBgDisabled;

      case AppActionState.inProgress:
        return AppTheme.buttonBgProgress;

      case AppActionState.active:
        return AppTheme.buttonBgActive;

      case AppActionState.error:
        return AppTheme.buttonBgError;

      case AppActionState.allowActions:
      case AppActionState.normal:
        return AppTheme.buttonBg;
    }
  }

  Color _foregroundColor() {
    switch (_state) {
      case AppActionState.disabled:
      case AppActionState.disallowActions:
        return AppTheme.buttonFgDisabled;

      case AppActionState.inProgress:
        return AppTheme.buttonFgProgress;

      case AppActionState.active:
        return AppTheme.buttonFgActive;

      case AppActionState.error:
        return AppTheme.buttonFgError;

      case AppActionState.allowActions:
      case AppActionState.normal:
        return AppTheme.buttonFg;
    }
  }

  // Helper methods previously provided by AppActionController
  AppActionState setAppState(AppActionState s) {
    if (mounted) setState(() => _state = s);
    return s;
  }

  AppActionState allowActions() => setAppState(AppActionState.allowActions);
  AppActionState disallowActions() => setAppState(AppActionState.disallowActions);
  AppActionState disable() => setAppState(AppActionState.disabled);
  AppActionState enable() => setAppState(AppActionState.normal);
  AppActionState normal() => setAppState(AppActionState.normal);
  AppActionState progress() => setAppState(AppActionState.inProgress);
  AppActionState active() => setAppState(AppActionState.active);
  AppActionState error() => setAppState(AppActionState.error);
  AppActionState reset() => setAppState(AppActionState.normal);
}

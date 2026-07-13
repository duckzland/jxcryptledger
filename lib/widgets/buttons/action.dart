import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum WidgetsButtonActionState {
  transparent(background: Colors.transparent, foreground: AppTheme.buttonFg),

  allowActions(background: AppTheme.buttonBg, foreground: AppTheme.buttonFg),

  disallowActions(background: AppTheme.buttonBgDisabled, foreground: AppTheme.buttonFgDisabled),

  disabled(background: AppTheme.buttonBgDisabled, foreground: AppTheme.buttonFgDisabled),

  inProgress(background: AppTheme.buttonBgProgress, foreground: AppTheme.buttonFgProgress),

  active(background: AppTheme.buttonBgActive, foreground: AppTheme.buttonFgActive),

  error(background: AppTheme.buttonBgError, foreground: AppTheme.buttonFgError),

  normal(background: AppTheme.buttonBg, foreground: AppTheme.buttonFg),

  primary(background: AppTheme.buttonBgPrimary, foreground: AppTheme.buttonFgPrimary),

  action(background: AppTheme.buttonBgAction, foreground: AppTheme.buttonFgAction),

  warning(background: AppTheme.buttonBgWarning, foreground: AppTheme.buttonFgWarning);

  final Color background;
  final Color foreground;

  const WidgetsButtonActionState({required this.background, required this.foreground});

  Color resolveBackground(WidgetsButtonActionState initialState) {
    if (this == WidgetsButtonActionState.inProgress) {
      switch (initialState) {
        case WidgetsButtonActionState.action:
          return AppTheme.buttonBgAction;
        case WidgetsButtonActionState.warning:
          return AppTheme.buttonBgWarning;
        default:
          return AppTheme.buttonBgProgress;
      }
    }
    return background;
  }
}

class WidgetsButtonsAction extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final FutureOr<void> Function(WidgetsButtonsActionState state)? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final FutureOr<void> Function(WidgetsButtonsActionState state)? evaluator;
  final WidgetsButtonActionState initialState;
  final double? iconSize;
  final Size? minimumSize;
  final bool persistBg;
  final bool initialTransparent;
  final bool centered;

  const WidgetsButtonsAction({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.padding,
    this.evaluator,
    this.initialState = WidgetsButtonActionState.normal,
    this.iconSize,
    this.minimumSize,
    this.persistBg = true,
    this.initialTransparent = false,
    this.centered = true,
  });

  @override
  State<WidgetsButtonsAction> createState() => WidgetsButtonsActionState();
}

class WidgetsButtonsActionState extends State<WidgetsButtonsAction> {
  WidgetsButtonActionState _state = WidgetsButtonActionState.normal;

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
  void didUpdateWidget(covariant WidgetsButtonsAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runEvaluator();
  }

  bool get _disabled => _state == WidgetsButtonActionState.disabled || _state == WidgetsButtonActionState.disallowActions;

  bool get _inProgress => _state == WidgetsButtonActionState.inProgress;

  bool get _isActive => _state == WidgetsButtonActionState.active;

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor();
    final fg = _foregroundColor();
    final br = Color.lerp(bg, fg, 0.70)!;

    final button = ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || widget.persistBg || _state == WidgetsButtonActionState.inProgress) {
            return _backgroundColor();
          }

          return widget.initialTransparent ? Colors.transparent : AppTheme.buttonBg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || widget.persistBg || _state == WidgetsButtonActionState.inProgress) {
            return _foregroundColor();
          }
          return AppTheme.buttonFg;
        }),
        shadowColor: WidgetStateProperty.all(br),
        padding: WidgetStateProperty.all(widget.padding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
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

    if ((widget.label != null && widget.label!.isNotEmpty) && widget.icon != null) {
      return Row(
        spacing: 8,
        mainAxisSize: widget.centered ? MainAxisSize.min : MainAxisSize.max,
        children: [
          SizedBox(
            width: widget.iconSize ?? 18,
            height: widget.iconSize ?? 18,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(widget.icon, size: widget.iconSize ?? 18, color: fg),
            ),
          ),
          Text(widget.label!, softWrap: false, overflow: TextOverflow.visible),
        ],
      );
    }

    if (widget.icon != null) {
      return SizedBox(
        width: widget.iconSize ?? 18,
        height: widget.iconSize ?? 18,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Icon(widget.icon, size: widget.iconSize ?? 18, color: fg),
        ),
      );
    }

    return Text(widget.label ?? "", softWrap: false, overflow: TextOverflow.visible);
  }

  Color _backgroundColor() {
    return _state.resolveBackground(widget.initialState);
  }

  Color _foregroundColor() {
    return _state.foreground;
  }

  // Helper methods previously provided by AppActionController
  WidgetsButtonActionState setAppState(WidgetsButtonActionState s) {
    if (mounted && _state != s) {
      setState(() => _state = s);
    }
    return s;
  }

  WidgetsButtonActionState allowActions() => setAppState(WidgetsButtonActionState.allowActions);
  WidgetsButtonActionState disallowActions() => setAppState(WidgetsButtonActionState.disallowActions);
  WidgetsButtonActionState disable() => setAppState(WidgetsButtonActionState.disabled);
  WidgetsButtonActionState enable() => setAppState(WidgetsButtonActionState.normal);
  WidgetsButtonActionState normal() => setAppState(WidgetsButtonActionState.normal);
  WidgetsButtonActionState primary() => setAppState(WidgetsButtonActionState.primary);
  WidgetsButtonActionState progress() => setAppState(WidgetsButtonActionState.inProgress);
  WidgetsButtonActionState active() => setAppState(WidgetsButtonActionState.active);
  WidgetsButtonActionState error() => setAppState(WidgetsButtonActionState.error);
  WidgetsButtonActionState reset() => setAppState(WidgetsButtonActionState.normal);
  WidgetsButtonActionState action() => setAppState(WidgetsButtonActionState.action);
  WidgetsButtonActionState warning() => setAppState(WidgetsButtonActionState.warning);
}

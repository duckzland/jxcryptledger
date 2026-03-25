import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum WidgetsButtonActionState { allowActions, disallowActions, disabled, inProgress, active, error, normal, primary, action, warning }

class WidgetsButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final FutureOr<void> Function(WidgetsButtonState state)? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final FutureOr<void> Function(WidgetsButtonState state)? evaluator;
  final WidgetsButtonActionState initialState;
  final double? iconSize;
  final Size? minimumSize;
  final bool persistBg;

  const WidgetsButton({
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
  });

  @override
  State<WidgetsButton> createState() => WidgetsButtonState();
}

class WidgetsButtonState extends State<WidgetsButton> {
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
  void didUpdateWidget(covariant WidgetsButton oldWidget) {
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

          return AppTheme.buttonBg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || widget.persistBg || _state == WidgetsButtonActionState.inProgress) {
            return _foregroundColor();
          }
          return AppTheme.buttonFg;
        }),
        shadowColor: WidgetStateProperty.all(br),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        elevation: WidgetStateProperty.all(0),
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

  // Not Working crash on Alert -> Wrap and some icon only button sizing weird
  // minimumSize: WidgetStateProperty.all(_minSize),
  // padding: WidgetStateProperty.all(EdgeInsets.zero),
  // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  // LayoutBuilder _layoutBuilder(Color fg) {
  //   return LayoutBuilder(
  //     builder: (context, constraints) {
  //       double tw = widget.icon != null ? widget.iconSize ?? 0 : 0;

  //       if (widget.label != null) {
  //         if (widget.icon != null) {
  //           tw += 8;
  //         }

  //         final TextPainter textPainter = TextPainter(
  //           text: TextSpan(
  //             text: widget.label ?? "",
  //             style: TextStyle(color: fg),
  //           ),
  //           maxLines: 1,
  //           textDirection: TextDirection.ltr,
  //         )..layout();

  //         tw += textPainter.width;
  //       }

  //       final EdgeInsetsGeometry geometry = widget.padding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 8);
  //       final EdgeInsets resolvedPadding = geometry.resolve(Directionality.of(context));

  //       final double left = resolvedPadding.left;
  //       final double right = resolvedPadding.right;
  //       final double top = resolvedPadding.top;
  //       final double bottom = resolvedPadding.bottom;

  //       EdgeInsets pads = EdgeInsets.only(left: left, right: right, top: top, bottom: top);

  //       if (widget.label != null) {
  //         final maxSpace = constraints.maxWidth - tw;
  //         if (maxSpace < (left + right)) {
  //           double ratio = (left + right) > 0 ? left / (left + right) : 0.5;
  //           double newLeft = (maxSpace * ratio).clamp(8.0, left);
  //           double newRight = (maxSpace * (1 - ratio)).clamp(8.0, right);
  //           pads = EdgeInsets.only(left: newLeft, right: newRight, top: top, bottom: bottom);
  //         }
  //       }

  //       return Padding(padding: pads, child: _buildChild(fg));
  //     },
  //   );
  // }

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
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
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
    switch (_state) {
      case WidgetsButtonActionState.disabled:
      case WidgetsButtonActionState.disallowActions:
        return AppTheme.buttonBgDisabled;

      case WidgetsButtonActionState.inProgress:
        switch (widget.initialState) {
          case WidgetsButtonActionState.action:
            return AppTheme.buttonBgAction;

          case WidgetsButtonActionState.warning:
            return AppTheme.buttonBgWarning;

          default:
            return AppTheme.buttonBgProgress;
        }

      case WidgetsButtonActionState.active:
        return AppTheme.buttonBgActive;

      case WidgetsButtonActionState.error:
        return AppTheme.buttonBgError;

      case WidgetsButtonActionState.primary:
        return AppTheme.buttonBgPrimary;

      case WidgetsButtonActionState.action:
        return AppTheme.buttonBgAction;

      case WidgetsButtonActionState.warning:
        return AppTheme.buttonBgWarning;

      case WidgetsButtonActionState.allowActions:
      case WidgetsButtonActionState.normal:
        return AppTheme.buttonBg;
    }
  }

  Color _foregroundColor() {
    switch (_state) {
      case WidgetsButtonActionState.disabled:
      case WidgetsButtonActionState.disallowActions:
        return AppTheme.buttonFgDisabled;

      case WidgetsButtonActionState.inProgress:
        return AppTheme.buttonFgProgress;

      case WidgetsButtonActionState.active:
        return AppTheme.buttonFgActive;

      case WidgetsButtonActionState.primary:
        return AppTheme.buttonFgPrimary;

      case WidgetsButtonActionState.action:
        return AppTheme.buttonFgAction;

      case WidgetsButtonActionState.warning:
        return AppTheme.buttonFgWarning;

      case WidgetsButtonActionState.error:
        return AppTheme.buttonFgError;

      case WidgetsButtonActionState.allowActions:
      case WidgetsButtonActionState.normal:
        return AppTheme.buttonFg;
    }
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

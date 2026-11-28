import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'panel.dart';

class WidgetsAsyncLoader extends StatelessWidget {
  final Future<void> future;
  final Widget child;
  final String? message;

  const WidgetsAsyncLoader({super.key, required this.future, required this.child, this.message});

  static Widget _content(String? message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const CircularProgressIndicator(),
        if (message != null) Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  static Widget indicator({String? message}) {
    return RepaintBoundary(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: WidgetsPanel(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            background: AppTheme.dialogBg,
            borderRadius: 12,
            child: _content(message),
          ),
        ),
      ),
    );
  }

  static Widget mask({String? message, double opacity = 0.75}) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ColoredBox(
          color: AppTheme.barrierBg.withValues(alpha: opacity),
          child: Center(child: _content(message)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(body: indicator(message: message));
        }
        return child;
      },
    );
  }
}

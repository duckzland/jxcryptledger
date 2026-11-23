import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {PointerDeviceKind.touch, PointerDeviceKind.mouse};

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        final theme = ScrollbarTheme.of(context);
        return RawScrollbar(
          controller: details.controller,
          thumbVisibility: theme.thumbVisibility?.resolve({}),
          thickness: theme.thickness?.resolve({}),
          radius: theme.radius,
          thumbColor: theme.thumbColor?.resolve({}),
          crossAxisMargin: theme.crossAxisMargin ?? 0.0,
          timeToFade: const Duration(seconds: 2),
          fadeDuration: const Duration(milliseconds: 1500),
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}

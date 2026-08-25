import 'package:flutter/material.dart';

import '../context_menu.dart';

class WidgetsTextSelectable extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;

  final bool selectable;

  const WidgetsTextSelectable(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Text(text, style: style, textAlign: textAlign, maxLines: maxLines, softWrap: softWrap, overflow: overflow);

    if (!selectable) {
      return content;
    }

    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return WidgetsContextMenu(
          anchor: selectableRegionState.contextMenuAnchors.primaryAnchor,
          buttonItems: selectableRegionState.contextMenuButtonItems,
        );
      },
      child: DefaultSelectionStyle(mouseCursor: SystemMouseCursors.text, child: content),
    );
  }
}

import 'package:flutter/material.dart';
import '../../app/theme.dart';

class WidgetsContextMenu extends StatelessWidget {
  final Offset anchor;
  final List<ContextMenuButtonItem> buttonItems;

  const WidgetsContextMenu({super.key, required this.anchor, required this.buttonItems});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = buttonItems.map((buttonItem) {
      return TextButton(
        onPressed: buttonItem.onPressed,
        style: AppTheme.contextMenuButton.copyWith(alignment: Alignment.centerLeft),
        child: Text(AdaptiveTextSelectionToolbar.getButtonLabel(context, buttonItem)),
      );
    }).toList();

    return Stack(
      children: [
        CustomSingleChildLayout(
          delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: anchor),
          child: IntrinsicWidth(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: AppTheme.menuPadding,
                decoration: AppTheme.contextMenuDecoration,
                constraints: const BoxConstraints(minWidth: 160),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

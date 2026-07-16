import 'package:flutter/material.dart';
import '../../../app/theme.dart';

import '../dialogs/alert.dart';
import '../dialogs/export.dart';
import '../dialogs/import.dart';
import '../dialogs/reset.dart';
import '../dialogs/show_form.dart';
import 'action.dart';

class WidgetsButtonsDropdown extends StatelessWidget {
  final List<Widget> children;
  final int maxVisible;
  final List<WidgetsButtonActionState> dotStates;
  final List<WidgetsButtonActionState> Function(MenuController menuController)? dotEvaluator;

  final double iconWidth;
  final double iconHeight;
  final double menuWidth;
  final bool menuAlignRight;

  final Listenable? listener;

  const WidgetsButtonsDropdown({
    super.key,
    required this.children,
    required this.maxVisible,
    required this.iconWidth,
    required this.iconHeight,
    required this.menuWidth,
    this.menuAlignRight = false,
    this.dotStates = const [],
    this.dotEvaluator,
    this.listener,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox();
    }

    if (listener != null) {
      return ListenableBuilder(
        listenable: listener!,
        builder: (context, _) {
          return buildButtons();
        },
      );
    }

    return buildButtons();
  }

  Widget buildButtons() {
    List<Widget> buttons;

    final visible = children.sublist(0, children.length <= maxVisible ? children.length : maxVisible).map((item) {
      if (item is WidgetsDialogsShowForm) {
        return item.copyWith(label: "");
      } else if (item is WidgetsDialogsAlert) {
        return item.copyWith(label: "");
      } else if (item is WidgetsDialogsExport) {
        return item.copyWith(label: "");
      } else if (item is WidgetsDialogsImport) {
        return item.copyWith(label: "");
      } else if (item is WidgetsDialogsReset) {
        return item.copyWith(label: "");
      }
      return item;
    }).toList();

    buttons = [...visible];

    if (children.length > maxVisible) {
      final inMenus = children.sublist(maxVisible).map((item) {
        if (item is WidgetsDialogsShowForm) {
          return item.copyWith(insideDropdown: true, padding: AppTheme.inputPadding);
        } else if (item is WidgetsDialogsAlert) {
          return item.copyWith(plainMode: true, padding: AppTheme.inputPadding);
        } else if (item is WidgetsDialogsExport) {
          return item.copyWith(insideDropdown: true, padding: AppTheme.inputPadding);
        } else if (item is WidgetsDialogsImport) {
          return item.copyWith(insideDropdown: true, padding: AppTheme.inputPadding);
        } else if (item is WidgetsDialogsReset) {
          return item.copyWith(insideDropdown: true, padding: AppTheme.inputPadding);
        }
        return item;
      }).toList();

      double offsetX = 0;
      if (menuAlignRight) {
        offsetX = (menuWidth - iconWidth) * -1;
      }

      buttons.add(
        MenuAnchor(
          animated: false,
          alignmentOffset: Offset(offsetX, 4),
          builder: (context, controller, child) {
            return Container(
              width: iconWidth,
              height: iconHeight,
              decoration: BoxDecoration(
                color: controller.isOpen ? AppTheme.menuBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(maxWidth: iconWidth, maxHeight: iconHeight),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                disabledColor: Colors.transparent,
                splashRadius: 6,
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: buildAdaptiveDots(controller),
              ),
            );
          },
          menuChildren: [
            SizedBox(
              width: menuWidth,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: inMenus),
            ),
          ],
        ),
      );
    }

    return Wrap(
      direction: Axis.horizontal,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: buttons,
    );
  }

  Widget buildAdaptiveDots(MenuController controller) {
    final states = dotEvaluator != null ? dotEvaluator?.call(controller) ?? [] : dotStates;
    final dotSize = (iconWidth / 7).clamp(3.0, 6.0);
    final dots = states.skip(maxVisible).take(6).toList();

    Widget dot(WidgetsButtonActionState s) => Container(
      width: dotSize,
      height: dotSize,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: s.background, shape: BoxShape.circle),
    );

    final columns = <List<Widget>>[];
    for (var i = 0; i < dots.length; i += 2) {
      final group = dots.skip(i).take(2).map(dot).toList();
      columns.add(group);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns.map((col) {
        return Column(mainAxisSize: MainAxisSize.min, children: col);
      }).toList(),
    );
  }
}

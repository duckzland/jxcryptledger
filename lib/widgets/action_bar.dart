import 'package:flutter/material.dart';

class WidgetsActionBar extends StatelessWidget {
  final Widget? leftActions;
  final Widget? mainActions;
  final Widget? rightActions;

  const WidgetsActionBar({super.key, this.leftActions, this.mainActions, this.rightActions});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leftActions),
              ),
              ?mainActions,
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: rightActions),
              ),
            ],
          );
        } else {
          return Wrap(
            direction: Axis.horizontal,
            runSpacing: 10,
            spacing: 10,
            runAlignment: WrapAlignment.center,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [?leftActions, ?mainActions, ?rightActions],
          );
        }
      },
    );
  }
}

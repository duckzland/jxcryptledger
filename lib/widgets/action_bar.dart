import 'dart:ui';

import 'package:flutter/material.dart';

class WidgetsActionBar extends StatelessWidget {
  final Widget? leftActions;
  final Widget? mainActions;
  final Widget? rightActions;

  final bool centering;

  const WidgetsActionBar({super.key, this.centering = false, this.leftActions, this.mainActions, this.rightActions});

  @override
  Widget build(BuildContext context) {
    final Key centerKey = UniqueKey();
    bool doCentering = centering;
    bool doShrinkWrap = true;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 560 && centering) {
          doCentering = false;
        }
        int sideAvailable = 0;
        if (leftActions != null) {
          sideAvailable++;
        }

        if (mainActions != null) {
          sideAvailable++;
        }

        if (rightActions != null) {
          sideAvailable++;
        }

        if (sideAvailable < 2) {
          doCentering = false;
          doShrinkWrap = false;
        }

        if (constraints.maxWidth > 760) {
          return Row(
            spacing: 12,
            children: [
              ?leftActions != null
                  ? Expanded(
                      child: Align(alignment: Alignment.centerLeft, child: leftActions),
                    )
                  : null,
              ?mainActions,
              ?rightActions != null
                  ? Expanded(
                      child: Align(alignment: Alignment.centerRight, child: rightActions),
                    )
                  : null,
            ],
          );
        } else {
          return Center(
            child: SizedBox(
              height: 50,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
                child: CustomScrollView(
                  shrinkWrap: doCentering ? false : doShrinkWrap,
                  scrollDirection: Axis.horizontal,
                  center: doCentering ? centerKey : null,
                  slivers: [
                    ?leftActions != null
                        ? SliverToBoxAdapter(
                            child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?leftActions]),
                          )
                        : null,
                    ?mainActions != null
                        ? SliverToBoxAdapter(
                            key: centerKey,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?mainActions]),
                            ),
                          )
                        : null,
                    ?rightActions != null
                        ? SliverToBoxAdapter(
                            child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?rightActions]),
                          )
                        : null,
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 560 && centering) {
          doCentering = false;
        }
        if (constraints.maxWidth > 760) {
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
          return Center(
            child: SizedBox(
              height: 50,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
                child: CustomScrollView(
                  shrinkWrap: doCentering ? false : true,
                  scrollDirection: Axis.horizontal,
                  center: doCentering ? centerKey : null,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?leftActions]),
                    ),
                    SliverToBoxAdapter(
                      key: centerKey,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?mainActions]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [?rightActions]),
                    ),
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

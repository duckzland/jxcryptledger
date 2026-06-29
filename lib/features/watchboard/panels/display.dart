import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../watchers/controller.dart';
import 'controller.dart';
import 'model.dart';
import 'buttons.dart';

class PanelsDisplay extends StatefulWidget {
  final PanelsModel tix;
  final double? prevRate;
  final bool isDragging;

  const PanelsDisplay({super.key, required this.tix, required this.isDragging, this.prevRate});

  @override
  State<PanelsDisplay> createState() => _PanelsDisplayState();
}

class _PanelsDisplayState extends State<PanelsDisplay> {
  PanelsController get _controller => locator<PanelsController>();
  CryptosController get _cryptosController => locator<CryptosController>();
  WatchersController get _wxController => locator<WatchersController>();

  static final List<StateSetter> _subscribers = [];

  static dynamic _activePanelId;

  @override
  void didUpdateWidget(covariant PanelsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.isBothEqual(oldWidget.tix, widget.tix)) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribers.add(setState);
  }

  @override
  void dispose() {
    _subscribers.remove(setState);
    super.dispose();
  }

  void _handleToggle() {
    final myId = widget.tix.tid;
    _activePanelId = (_activePanelId == myId) ? null : myId;

    for (final setter in _subscribers) {
      setter(() {});
    }
  }

  Color _resolveBackground() {
    final status = widget.tix.status;
    switch (status) {
      case 1:
        return AppTheme.green;
      case -1:
        return AppTheme.red;
      default:
        return AppTheme.panelBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tix = widget.tix;

    String sourceSymbol = _cryptosController.getSymbol(tix.srId) ?? "";
    String targetSymbol = _cryptosController.getSymbol(tix.rrId) ?? "";

    final fromText = "${Utils.formatSmartDouble(tix.srAmount)} $sourceSymbol to $targetSymbol";
    final toText = "${Utils.formatSmartDouble((tix.rate * tix.srAmount), maxDecimals: tix.digit, smartDecimal: true)} $targetSymbol";
    final rateText = "1 $sourceSymbol = ${Utils.formatSmartDouble(tix.rate, maxDecimals: tix.digit)} $targetSymbol";
    final inverseText = "1 $targetSymbol = ${Utils.formatSmartDouble((1 / tix.rate), maxDecimals: tix.digit)} $sourceSymbol";

    final bool isThisOneActive = _activePanelId == widget.tix.tid;

    final text = tix.rate > 0
        ? [
            Text(fromText, style: const TextStyle(height: 1.2, fontSize: 13, fontWeight: FontWeight.w600)),
            Flexible(
              child: Text(
                toText,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(height: 1.3, fontSize: 25, fontWeight: FontWeight.w700),
              ),
            ),
            Text(rateText, style: const TextStyle(height: 1.3, fontSize: 12, fontWeight: FontWeight.w400)),
            Text(inverseText, style: const TextStyle(height: 1.1, fontSize: 11, fontWeight: FontWeight.w400)),
          ]
        : [
            Text(
              tix.rate == -9999 ? "Fetching new rate..." : "Loading...",
              style: const TextStyle(height: 1.2, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ];

    final targetColor = _resolveBackground();
    final hsl = HSLColor.fromColor(targetColor);
    final startColor = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    final mutedColor = Color.lerp(AppTheme.separator, targetColor, 0.70)!;

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 300),
      tween: ColorTween(begin: startColor, end: targetColor),
      curve: Curves.easeInOut,
      builder: (context, Color? animatedBgColor, child) {
        return GestureDetector(
          onTap: _handleToggle,
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                WidgetsPanel(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 8),
                  background: animatedBgColor,
                  borderColor: mutedColor,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: text,
                    ),
                  ),
                ),

                AnimatedBuilder(
                  animation: _wxController,
                  builder: (context, _) {
                    final linked = _wxController.getLinked("panels-${widget.tix.tid}");

                    return Stack(
                      children: [
                        if (linked != null)
                          Positioned(
                            top: 8,
                            left: 6,
                            child: Icon(
                              Icons.add_alarm,
                              size: 16,
                              color: linked.isSpent ? AppTheme.textMuted.withAlpha(105) : AppTheme.text.withAlpha(205),
                            ),
                          ),

                        if (widget.tix.isLinked)
                          Positioned(
                            top: 8,
                            left: linked != null ? 24 : 6,
                            child: Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.text.withAlpha(205)),
                          ),

                        if (isThisOneActive && !widget.isDragging)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: PanelsButtons(tix: widget.tix, tixController: _controller, linkedWatcher: linked, onAction: () {}),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

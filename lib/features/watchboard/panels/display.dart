import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/math.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/numbers/flow.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/text/selectable.dart';
import '../../cryptos/controller.dart';
import '../../watchers/controller.dart';
import 'controller.dart';
import 'model.dart';
import 'buttons.dart';

class PanelsDisplay extends StatefulWidget {
  final PanelsModel tix;
  final bool isDragging;

  const PanelsDisplay({super.key, required this.tix, required this.isDragging});

  @override
  State<PanelsDisplay> createState() => _PanelsDisplayState();
}

class _PanelsDisplayState extends State<PanelsDisplay> {
  PanelsController get _controller => CoreLocator.getit<PanelsController>();
  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();
  WatchersController get _wxController => CoreLocator.getit<WatchersController>();

  static final List<StateSetter> _subscribers = [];

  static dynamic _activePanelId;

  Color _currentColor = AppTheme.panelBg;
  Decimal? _rate;

  @override
  void initState() {
    super.initState();
    _subscribers.add(setState);
    _currentColor = _resolveBackground();
  }

  @override
  void didUpdateWidget(covariant PanelsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.isBothEqual(oldWidget.tix, widget.tix)) {
      setState(() {});
    }
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

  @override
  Widget build(BuildContext context) {
    final bool isThisOneActive = _activePanelId == widget.tix.tid;

    final targetColor = _resolveBackground();
    bool colorChanged = targetColor != _currentColor;

    final hsl = HSLColor.fromColor(targetColor);
    final startColor = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();

    _currentColor = targetColor;

    return TweenAnimationBuilder<Color?>(
      duration: Duration(milliseconds: 400),
      tween: ColorTween(begin: colorChanged ? startColor : targetColor, end: targetColor),
      curve: Curves.easeOut,
      builder: (buildContext, Color? animatedBgColor, child) {
        Widget content = WidgetsPanel(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 8),
          background: animatedBgColor,
          borderColor: AppTheme.background,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _buildText(),
            ),
          ),
        );

        if (animatedBgColor != targetColor) {
          content = RepaintBoundary(child: content);
        }

        return MouseRegion(
          cursor: widget.isDragging ? SystemMouseCursors.move : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleToggle,
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                children: [
                  content,

                  ListenableBuilder(
                    listenable: _wxController,
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
          ),
        );
      },
    );
  }

  List<Widget> _buildText() {
    final tix = widget.tix;

    String sourceSymbol = _cryptosController.getSymbol(tix.srId) ?? "";
    String targetSymbol = _cryptosController.getSymbol(tix.rrId) ?? "";

    final pv = Utils.formatSmartDecimal(
      Math.multiply(tix.oldRate, tix.srAmount),
      maxDecimals: tix.digit,
      smartDecimal: true,
      limitDecimals: 15,
    );
    final tv = Utils.formatSmartDecimal(
      Math.multiply(tix.rate, tix.srAmount),
      maxDecimals: tix.digit,
      smartDecimal: true,
      limitDecimals: 15,
    );

    final tr = Utils.formatSmartDecimal(tix.rate, maxDecimals: tix.digit);
    final rtr = Utils.formatSmartDecimal(Math.divide(Decimal.one, tix.rate), maxDecimals: tix.digit);

    final fromText = "${Utils.formatSmartDecimal(tix.srAmount)} $sourceSymbol to $targetSymbol";
    final toText = "$tv $targetSymbol";

    final fromStyle = TextStyle(height: 1.2, fontWeight: FontWeight.w600);
    final toStyle = TextStyle(height: 1.3, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);

    final fromFontSize = fromText.length > 30 ? 12.0 : 13.0;
    final toFontSize = toText.length > 18 ? 22.0 : 25.0;

    final rate = _rate;
    _rate = tix.oldRate;

    final text = tix.rate > Decimal.zero
        ? [
            WidgetsTextSelectable(
              fromText,
              style: fromStyle.copyWith(fontSize: fromFontSize),
              selectable: !widget.isDragging,
            ),
            WidgetsNumbersFlow(
              begin: rate != null ? pv : null,
              end: tv,
              suffix: " $targetSymbol",
              style: toStyle.copyWith(fontSize: toFontSize),
              selectable: !widget.isDragging,
            ),
            WidgetsTextSelectable(
              "1 $sourceSymbol = $tr $targetSymbol",
              style: TextStyle(height: 1.3, fontSize: 12, fontWeight: FontWeight.w400),
              selectable: !widget.isDragging,
            ),
            WidgetsTextSelectable(
              "1 $targetSymbol = $rtr $sourceSymbol",
              style: TextStyle(height: 1.3, fontSize: 12, fontWeight: FontWeight.w400),
              selectable: !widget.isDragging,
            ),
          ]
        : [
            Text(
              tix.rate == Decimal.fromInt(-9999) ? "Fetching new rate..." : "Loading...",
              style: TextStyle(height: 1.2, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ];

    return text;
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
}

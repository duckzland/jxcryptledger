import 'package:flutter/material.dart';

import '../../../app/theme.dart' show AppTheme;
import '../../../core/locator.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import '../controller.dart';
import '../model.dart';
import 'buttons.dart';

class TickersWidgetsPanel extends StatefulWidget {
  final PanelsModel tix;
  final double? prevRate;
  final bool isDragging;

  const TickersWidgetsPanel({super.key, required this.tix, required this.isDragging, this.prevRate});

  @override
  State<TickersWidgetsPanel> createState() => _TickersWidgetsPanelState();
}

class _TickersWidgetsPanelState extends State<TickersWidgetsPanel> {
  CryptosController get _cryptosController => locator<CryptosController>();

  late final PanelsController _tixController;
  late final RatesController _ratesController;

  static final List<StateSetter> _subscribers = [];

  static dynamic _activePanelId;

  @override
  void initState() {
    super.initState();
    _tixController = locator<PanelsController>();
    _tixController.addListener(_onControllerChanged);

    _ratesController = locator<RatesController>();
    _ratesController.addListener(_onControllerChanged);

    _subscribers.add(setState);
  }

  @override
  void dispose() {
    _tixController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);
    _subscribers.remove(setState);

    super.dispose();
  }

  void _onControllerChanged() async {
    final tix = widget.tix;
    final newRate = await _ratesController.getStoredRate(tix.srId, tix.rrId);
    if (newRate != tix.rate) {
      tix.setRate(newRate);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _handleToggle() {
    final myId = widget.tix.tid;
    _activePanelId = (_activePanelId == myId) ? null : myId;

    for (final setter in _subscribers) {
      setter(() {});
    }
  }

  Color _resolveBackground() {
    final status = widget.tix.getStatus();
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

    final fromText = "${tix.srAmount} $sourceSymbol to $targetSymbol";
    final toText = "${(tix.rate! * tix.srAmount).toStringAsFixed(tix.digit)} $targetSymbol";
    final rateText = "1 $sourceSymbol = ${tix.rate?.toStringAsFixed(tix.digit)} $targetSymbol";
    final inverseText = "1 $targetSymbol = ${(1 / tix.rate!).toStringAsFixed(tix.digit)} $sourceSymbol";

    final bool isThisOneActive = _activePanelId == widget.tix.tid;

    final text = tix.rate != null && tix.rate! > 0
        ? [
            Text(fromText, style: Theme.of(context).textTheme.bodyMedium),
            Flexible(
              child: Text(
                toText,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(rateText, style: Theme.of(context).textTheme.bodySmall),
            Text(inverseText, style: Theme.of(context).textTheme.bodySmall),
          ]
        : [
            Text(
              tix.rate! == -9999 ? "Fetching new rate..." : "Loading...",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ];

    final targetColor = _resolveBackground();
    final hsl = HSLColor.fromColor(targetColor);
    final startColor = hsl.withLightness((hsl.lightness + 0.3).clamp(0.0, 1.0)).toColor();

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 500),
      tween: ColorTween(begin: startColor, end: targetColor),
      curve: Curves.easeOutQuart,
      builder: (context, Color? animatedBgColor, child) {
        return GestureDetector(
          onTap: _handleToggle,
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                WidgetsPanel(
                  background: animatedBgColor,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: text,
                    ),
                  ),
                ),
                if (isThisOneActive && !widget.isDragging)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TickersWidgetsButtons(
                      tix: tix,
                      onAction: () {
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

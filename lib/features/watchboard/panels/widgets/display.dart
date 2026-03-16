import 'package:flutter/material.dart';

import '../../../../app/theme.dart' show AppTheme;
import '../../../../core/locator.dart';
import '../../../../core/utils.dart';
import '../../../../widgets/panel.dart';
import '../../../cryptos/controller.dart';
import '../../../rates/controller.dart';
import '../../../watchers/controller.dart';
import '../../../watchers/model.dart';
import '../controller.dart';
import '../model.dart';
import 'buttons.dart';

class PanelsWidgetsDisplay extends StatefulWidget {
  final PanelsModel tix;
  final double? prevRate;
  final bool isDragging;

  const PanelsWidgetsDisplay({super.key, required this.tix, required this.isDragging, this.prevRate});

  @override
  State<PanelsWidgetsDisplay> createState() => _PanelsWidgetsDisplayState();
}

class _PanelsWidgetsDisplayState extends State<PanelsWidgetsDisplay> {
  CryptosController get _cryptosController => locator<CryptosController>();

  late final PanelsController _tixController;
  late final RatesController _ratesController;

  static final List<StateSetter> _subscribers = [];

  static dynamic _activePanelId;

  late final WatchersController _wxController;

  WatchersModel? _linkedWatcher;

  @override
  void initState() {
    super.initState();
    _tixController = locator<PanelsController>();
    _tixController.addListener(_onControllerChanged);

    _ratesController = locator<RatesController>();
    _ratesController.addListener(_onControllerChanged);

    _wxController = locator<WatchersController>();
    _wxController.addListener(_onWatcherChanged);

    _linkedWatcher = _wxController.getLinked("panels-${widget.tix.tid}");

    _subscribers.add(setState);
  }

  @override
  void dispose() {
    _tixController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);
    _wxController.removeListener(_onWatcherChanged);
    _subscribers.remove(setState);

    super.dispose();
  }

  void _onWatcherChanged() async {
    final tix = widget.tix;
    if (mounted) {
      setState(() {
        _linkedWatcher = _wxController.getLinked("panels-${tix.tid}");
      });
    }
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

    final fromText = "${Utils.formatSmartDouble(tix.srAmount)} $sourceSymbol to $targetSymbol";
    final toText = "${Utils.formatSmartDouble((tix.rate! * tix.srAmount), maxDecimals: tix.digit, smartDecimal: true)} $targetSymbol";
    final rateText = "1 $sourceSymbol = ${Utils.formatSmartDouble(tix.rate!, maxDecimals: tix.digit)} $targetSymbol";
    final inverseText = "1 $targetSymbol = ${Utils.formatSmartDouble((1 / tix.rate!), maxDecimals: tix.digit)} $sourceSymbol";

    final bool isThisOneActive = _activePanelId == widget.tix.tid;

    final text = tix.rate != null && tix.rate! > 0
        ? [
            Text(fromText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1, fontSize: 16, fontWeight: FontWeight.w500)),
            Flexible(
              child: Text(
                toText,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.3, fontSize: 27, fontWeight: FontWeight.bold),
              ),
            ),
            Text(rateText, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3, fontSize: 14, fontWeight: FontWeight.w400)),
            Text(
              inverseText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.1, fontSize: 12, fontWeight: FontWeight.w400),
            ),
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
    final mutedColor = Color.lerp(AppTheme.separator, targetColor, 0.70)!;

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
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 12),
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
                if (_linkedWatcher != null)
                  Positioned(
                    top: 8,
                    left: 6,
                    child: Icon(
                      Icons.add_alarm,
                      size: 16,
                      color: _linkedWatcher!.isSpent() ? AppTheme.textMuted.withAlpha(105) : AppTheme.text.withAlpha(205),
                    ),
                  ),

                if (tix.isLinked())
                  Positioned(
                    top: 8,
                    left: _linkedWatcher != null ? 24 : 6,
                    child: Icon(Icons.account_balance_wallet, size: 16, color: AppTheme.text.withAlpha(205)),
                  ),

                if (isThisOneActive && !widget.isDragging)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PanelsWidgetsButtons(
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

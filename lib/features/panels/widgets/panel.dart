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

  const TickersWidgetsPanel({super.key, required this.tix, this.prevRate});

  @override
  State<TickersWidgetsPanel> createState() => _TickersWidgetsPanelState();
}

class _TickersWidgetsPanelState extends State<TickersWidgetsPanel> {
  CryptosController get _cryptosController => locator<CryptosController>();

  late final PanelsController _tixController;
  late final RatesController _ratesController;

  bool _showAction = false;

  @override
  void initState() {
    super.initState();
    _tixController = locator<PanelsController>();
    _tixController.addListener(_onControllerChanged);

    _ratesController = locator<RatesController>();
    _ratesController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _tixController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);

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

    return GestureDetector(
      onTap: () => setState(() => _showAction = !_showAction),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            WidgetsPanel(
              background: _resolveBackground(),
              child: SizedBox(
                width: double.infinity,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: text),
              ),
            ),
            if (_showAction)
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
  }
}

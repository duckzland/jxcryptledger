import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../core/locator.dart';
import '../../widgets/action_bar.dart';
import '../../widgets/button.dart';
import '../../widgets/panel.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../cryptos/controller.dart';
import 'screens/qrcode.dart';
import 'screens/calculator.dart';
import 'screens/converter.dart';

enum ToolsViewMode { calculator, converter, qrcode }

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  ToolsViewMode _viewMode = ToolsViewMode.calculator;
  final CryptosController _cryptosController = locator<CryptosController>();

  @override
  void initState() {
    super.initState();
    _cryptosController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _cryptosController.removeListener(_onControllerChanged);

    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _changePageTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cryptosController.isEmpty()) {
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before using tools.')),
        ],
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          children: [
            const SizedBox(height: 10),
            WidgetsActionBar(mainActions: _buildAction()),
            const SizedBox(height: 16),
            Expanded(child: _buildScreen()),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsButton(
            icon: Icons.calculate,
            padding: const EdgeInsets.all(8),
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "Calculator",
            evaluator: (s) {
              if (_viewMode == ToolsViewMode.calculator) {
                s.active();
              } else {
                s.normal();
              }
            },
            onPressed: (_) {
              setState(() {
                _viewMode = ToolsViewMode.calculator;
              });
            },
          ),

          WidgetsButton(
            icon: Icons.swap_horiz,
            padding: const EdgeInsets.all(8),
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "Converter",
            evaluator: (s) {
              if (_viewMode == ToolsViewMode.converter) {
                s.active();
              } else {
                s.normal();
              }
            },
            onPressed: (_) {
              setState(() {
                _viewMode = ToolsViewMode.converter;
              });
            },
          ),

          WidgetsButton(
            icon: Icons.qr_code_2,
            padding: const EdgeInsets.all(8),
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "QR Generator",
            evaluator: (s) {
              if (_viewMode == ToolsViewMode.qrcode) {
                s.active();
              } else {
                s.normal();
              }
            },
            onPressed: (_) {
              setState(() {
                _viewMode = ToolsViewMode.qrcode;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case ToolsViewMode.calculator:
        _changePageTitle("Calculator");

        return ToolsCalculatorView();

      case ToolsViewMode.converter:
        _changePageTitle("Converter");

        return ToolsConverterView();

      case ToolsViewMode.qrcode:
        _changePageTitle("QR Code Generator");

        return ToolsQRGeneratorView();
    }
  }
}

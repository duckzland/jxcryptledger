import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../widgets/button.dart';
import '../../widgets/panel.dart';
import 'screens/calculator.dart';

enum ToolsViewMode { calculator }

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  ToolsViewMode _viewMode = ToolsViewMode.calculator;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _changePageTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: SizedBox()),
                // _buildAction(),
                Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    return WidgetsPanel(
      child: Wrap(
        spacing: 4,
        children: [
          WidgetButton(
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
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case ToolsViewMode.calculator:
        _changePageTitle("Calculator");

        return ToolsCalculatorView();
    }
  }
}

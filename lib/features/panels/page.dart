import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../../widgets/button.dart';
import '../../widgets/layouts/sliver_grid.dart';
import '../../widgets/notify.dart';
import '../../widgets/panel.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../cryptos/controller.dart';
import '../tickers/controller.dart';
import 'controller.dart';
import 'form.dart';
import 'widgets/panel.dart';
import 'widgets/ticker.dart';

class PanelsPage extends StatefulWidget {
  const PanelsPage({super.key});

  @override
  State<PanelsPage> createState() => _PanelsPageState();
}

class _PanelsPageState extends State<PanelsPage> {
  late final PanelsController _panelsController;
  late final TickersController _tickersController;
  late final CryptosController _cryptosController;

  @override
  void initState() {
    super.initState();
    _panelsController = locator<PanelsController>();
    _panelsController.load();
    _panelsController.addListener(_onControllerChanged);

    _tickersController = locator<TickersController>();
    _tickersController.load();

    _cryptosController = locator<CryptosController>();
    _cryptosController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    super.dispose();
    _panelsController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showAddTickerDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: _buildForm(dialogContext)),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete All Tickers"),
            content: const Text(
              "This will delete all tickers.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Delete',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _panelsController.wipe();

                    Navigator.pop(dialogContext);

                    widgetsNotifySuccess("All tickers deleted.");
                  } catch (e) {
                    widgetsNotifyError("Failed to delete tickers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Import Tickers"),
            content: const Text(
              "This will erase all existing ticker before inserting new data from the selected file.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Import',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _showImportFileSelector();

                    Navigator.pop(dialogContext);
                  } catch (e) {
                    widgetsNotifyError("Failed to import tickers.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportFileSelector() async {
    final json = await _panelsController.exportDatabase();
    if (json.isEmpty) {
      widgetsNotifyError("Failed to export database.");
      return;
    }

    final suggestedName = "tixs_${DateTime.now().millisecondsSinceEpoch}.json";
    final saveLocation = await getSaveLocation(suggestedName: suggestedName, confirmButtonText: "Save");

    if (saveLocation == null || saveLocation.path.isEmpty) {
      widgetsNotifyError("Export cancelled.");
      return;
    }

    try {
      final file = File(saveLocation.path);
      await file.writeAsString(json);
      widgetsNotifySuccess("Database exported successfully.");
    } catch (e) {
      logln("Failed to save export file: $e");
      widgetsNotifyError("Failed to save exported file.");
    }
  }

  Future<void> _showImportFileSelector() async {
    try {
      final typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        widgetsNotifyError("No file selected.");
        return;
      }

      final json = await file.readAsString();
      await _panelsController.importDatabase(json);

      widgetsNotifySuccess("Database imported successfully.");
    } on ValidationException catch (e) {
      widgetsNotifyError(e.userMessage);
    } catch (e) {
      logln("Import failed: $e");
      widgetsNotifyError("Import failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cryptosController.hasAny()) {
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding tickers.')),
        ],
      );
    }

    if (_panelsController.items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
              title: "Add Ticker",
              addTitle: "Add New",
              addTooltip: "Create new ticker entry",
              addEvaluator: () => _cryptosController.hasAny(),
              importTitle: "Import",
              importTooltip: "Import tickers to database",
              importEvaluator: () => true,
              importCallback: (json) async => await _panelsController.importDatabase(json),
              addForm: _buildForm,
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                _buildAction(),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: _buildTickers())]),

            const SizedBox(height: 12),
            Flexible(flex: 10, fit: FlexFit.loose, child: _buildPanels()),
          ],
        ),
      ),
    );
  }

  Widget _buildPanels() {
    final items = _panelsController.items.toList();
    items.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMinWidth(
        minCrossAxisExtent: 320,
        itemHeight: 122,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        horizontalPadding: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final tx = items[index];
        return TickersWidgetsPanel(tix: tx);
      },
    );
  }

  Widget _buildTickers() {
    final items = _tickersController.items.toList()..sort((a, b) => a.order.compareTo(b.order));

    return LayoutBuilder(
      builder: (context, constraints) {
        const baseWidth = 140.0;
        const spacing = 8.0;
        const totalTickers = 8;
        const itemHeight = 50.0;
        final effectiveWidth = baseWidth + spacing;
        final maxPerRow = (constraints.maxWidth / effectiveWidth).floor().clamp(1, totalTickers);

        int perRow;
        if (maxPerRow >= 8) {
          perRow = 8;
        } else if (maxPerRow >= 4) {
          perRow = 4;
        } else if (maxPerRow >= 2) {
          perRow = 2;
        } else {
          perRow = 1;
        }

        final rows = (totalTickers / perRow).ceil();
        final newWidth = (constraints.maxWidth / perRow) - spacing;
        final tickerHeight = itemHeight * rows + ((rows - 1) * spacing);

        return SizedBox(
          height: tickerHeight,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithMinWidth(
              minCrossAxisExtent: newWidth > 140 ? newWidth : 140,
              itemHeight: 50,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              horizontalPadding: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tx = items[index];
              return TickersWidgetsTicker(tix: tx);
            },
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext dialogContext) {
    return Center(
      child: PanelsForm(
        onSave: (e) async {
          if (e == null) {
            Navigator.pop(dialogContext);
            return;
          }

          if (e is ValidationException) {
            widgetsNotifyError(e.userMessage, ctx: context);
            return;
          }

          widgetsNotifyError(e.toString(), ctx: context);
        },
      ),
    );
  }

  Widget _buildAction() {
    return WidgetsPanel(
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsButton(
            key: Key("import-button-batch"),
            icon: Icons.arrow_downward,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.primary,
            tooltip: "Import tickers to database",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showImportDialog(context),
            evaluator: (s) {},
          ),
          WidgetsButton(
            key: Key("export-button-batch"),
            icon: Icons.arrow_upward,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.action,
            tooltip: "Export tickers from database",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showExportFileSelector(),
            evaluator: (s) {
              if (_panelsController.isEmpty()) {
                s.disable();
              } else {
                s.action();
              }
            },
          ),
          WidgetsButton(
            key: Key("wipe-button-batch"),
            icon: Icons.delete_sweep,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.error,
            tooltip: "Delete all tickers",
            iconSize: 20,
            minimumSize: const Size(40, 40),
            onPressed: (_) => _showDeleteDialog(context),
            evaluator: (s) {
              if (_panelsController.isEmpty()) {
                s.disable();
              } else {
                s.error();
              }
            },
          ),
          WidgetsButton(
            icon: Icons.candlestick_chart_outlined,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.action,
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "Add new tickers",
            evaluator: (s) => s.action(),
            onPressed: (_) {
              _showAddTickerDialog();
            },
          ),
        ],
      ),
    );
  }
}

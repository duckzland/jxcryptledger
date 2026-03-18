import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../app/exceptions.dart';
import '../../app/layout.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/dialogs/alert.dart';
import '../../widgets/dialogs/show_form.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/layouts/sliver_grid.dart';
import '../../widgets/notify.dart';
import '../../widgets/panel.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../cryptos/controller.dart';
import 'tickers/controller.dart';
import 'panels/controller.dart';
import 'panels/form.dart';
import 'panels/widgets/display.dart';
import 'tickers/display.dart';

class WatchboardPage extends StatefulWidget {
  const WatchboardPage({super.key});

  @override
  State<WatchboardPage> createState() => _WatchboardPageState();
}

class _WatchboardPageState extends State<WatchboardPage> {
  late final PanelsController _pxController;
  late final TickersController _tixController;
  late final CryptosController _cryptosController;

  bool _enableDrag = false;
  bool _enableTickers = true;
  bool _hasLinked = false;

  DateTime _lastPress = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pxController = locator<PanelsController>();
    _pxController.load();
    _pxController.addListener(_onControllerChanged);

    _tixController = locator<TickersController>();
    _tixController.load();
    _tixController.addListener(_onControllerChanged);

    _cryptosController = locator<CryptosController>();
    _cryptosController.addListener(_onControllerChanged);

    _hasLinked = _pxController.hasLinked();

    _changePageTitle("Crypto Watchboard");
  }

  @override
  void dispose() {
    _pxController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);
    _tixController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _hasLinked = _pxController.hasLinked();
      });
    }
  }

  void _changePageTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cryptosController.isEmpty()) {
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding watchboard.')),
        ],
      );
    }

    if (_pxController.isEmpty()) {
      return Column(
        children: [
          Expanded(
            child: WidgetsScreensEmpty(
              title: "Add Watchboard",
              addTitle: "Add New",
              addTooltip: "Create new watchboard entry",
              addEvaluator: () => _cryptosController.isEmpty(),
              importTitle: "Import",
              importTooltip: "Import watchboard to database",
              importEvaluator: () => true,
              importCallback: (json) async {
                await _pxController.importDatabase(json);
                await _pxController.scheduleRates();
                await _tixController.refreshRates();
              },
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
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 20, children: [_buildDatabaseAction()]),
                  ),
                ),
                _buildMainAction(),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(spacing: 20, children: [_buildLinkedAction()]),
                  ),
                ),
              ],
            ),
            if (_enableTickers) SizedBox(height: 16),
            if (_enableTickers) Row(children: [Expanded(child: _buildTickers())]),

            const SizedBox(height: 12),
            Flexible(flex: 10, fit: FlexFit.loose, child: _buildPanels()),
          ],
        ),
      ),
    );
  }

  Widget _buildPanels() {
    final items = _pxController.items.toList();
    items.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    return ReorderableGridView.builder(
      gridDelegate: SliverGridDelegateWithMinWidth(
        minCrossAxisExtent: 320,
        itemHeight: 110,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        horizontalPadding: 12,
      ),
      dragEnabled: _enableDrag,
      dragStartDelay: Duration(microseconds: 10),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final tx = items[index];
        return PanelsWidgetsDisplay(key: ValueKey(tx.tid), tix: tx, isDragging: _enableDrag);
      },
      dragWidgetBuilder: (index, child) {
        return Material(color: Colors.transparent, elevation: 0, child: child);
      },
      onReorder: (oldIndex, newIndex) {
        final moved = items.removeAt(oldIndex);
        items.insert(newIndex, moved);

        for (var i = 0; i < items.length; i++) {
          items[i].order = i;
        }
        _pxController.updateOrder(items);
      },
    );
  }

  Widget _buildTickers() {
    final items = _tixController.items.toList()..sort((a, b) => a.order.compareTo(b.order));

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
          child: ReorderableGridView.builder(
            gridDelegate: SliverGridDelegateWithMinWidth(
              minCrossAxisExtent: newWidth > 140 ? newWidth : 140,
              itemHeight: 50,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              horizontalPadding: 8,
            ),
            dragEnabled: _enableDrag,
            dragStartDelay: Duration(microseconds: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tx = items[index];
              return TickersDisplay(key: ValueKey(tx.tid), tix: tx);
            },
            dragWidgetBuilder: (index, child) {
              return Material(color: Colors.transparent, elevation: 0, child: child);
            },
            onReorder: (oldIndex, newIndex) {
              final moved = items.removeAt(oldIndex);
              items.insert(newIndex, moved);

              for (var i = 0; i < items.length; i++) {
                items[i].order = i;
              }
              _tixController.updateOrder(items);
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

  Widget _buildMainAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsButton(
            icon: Icons.remove_red_eye,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.normal,
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: _enableTickers ? "Hide Watchboard Tickers" : "Show Watchboard Tickers",
            evaluator: (s) {
              _enableTickers ? s.primary() : s.normal();
            },
            onPressed: (_) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                setState(() {
                  _enableTickers = !_enableTickers;
                });
              });
            },
          ),
          WidgetsButton(
            icon: Icons.drag_indicator,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.normal,
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: _enableDrag ? "Turn off watchboard dragging" : "Turn on watchboard dragging",
            evaluator: (s) {
              _enableDrag ? s.primary() : s.normal();
            },
            onPressed: (_) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                final now = DateTime.now();
                if (now.difference(_lastPress).inMilliseconds < 500) {
                  return;
                }
                setState(() {
                  _lastPress = now;
                  _enableDrag = !_enableDrag;
                });

                widgetsNotifyClear();
                widgetsNotifySuccess(_enableDrag ? "Watchboard dragging enabled." : "Watchboard dragging disabled.");
              });
            },
          ),
          WidgetsDialogsShowForm(
            key: const Key("add-button"),
            tooltip: "Add new watchboard",
            buildForm: _buildForm,
            evaluator: (s) => s.action(),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsDialogsAlert(
            icon: Icons.delete_forever,
            initialState: WidgetsButtonActionState.error,
            tooltip: "Delete linked watchboard",
            evaluator: (s) {
              _hasLinked ? s.error() : s.disable();
            },
            dialogTitle: "Delete All Linked Watchboard",
            dialogMessage:
                "This will delete all linked watchboard entry.\n"
                "This action cannot be undone.",
            dialogConfirmLabel: "Delete",
            actionStartCallback: _pxController.wipeLinked,
            actionSuccessMessage: "All linked watchboard deleted.",
            actionErrorMessage: "Failed to delete linked watchboard.",
          ),

          WidgetsDialogsAlert(
            icon: Icons.line_axis,
            initialState: WidgetsButtonActionState.primary,
            tooltip: "Update linked watchboard",
            evaluator: (s) {
              _hasLinked ? s.primary() : s.disable();
            },
            dialogTitle: "Update Linked Watchboard",
            dialogMessage:
                "This will update all the linked watchboard.\n"
                "This action cannot be undone.",
            dialogConfirmLabel: "Update",
            actionCompleteCallback: () async {
              try {
                bool updated = await _pxController.updateLinked();
                if (updated) {
                  widgetsNotifySuccess("All linked watchboard updated.");
                } else {
                  widgetsNotifyWarning("Linked watchboard checked, but no additional data requires updating.");
                }
              } catch (e) {
                rethrow;
              }
            },
            actionErrorMessage: "Failed to update linked watchboard.",
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseAction() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        children: [
          WidgetsDialogsImport(
            key: Key("import-button-batch"),
            tooltip: "Import watchboard to database",
            showDialogBeforeImport: true,
            onImport: (String json) async {
              await _pxController.importDatabase(json);
              await _pxController.scheduleRates();
              await _tixController.refreshRates();
            },
            evaluator: (s) {},
          ),
          WidgetsDialogsExport(
            key: const Key("export-button-batch"),
            tooltip: "Export watchboard from database",
            suggestedPrefix: "wbx_",
            onExport: _pxController.exportDatabase,
            isEmpty: _pxController.isEmpty,
          ),
          WidgetsDialogsReset(
            key: const Key("reset-button-batch"),
            tooltip: "Reset watchboard database",
            dialogTitle: "Reset Watchboard Database",
            dialogMessage:
                "This will delete all watchboard entries.\n"
                "This action cannot be undone.",
            onWipe: () async {
              await _pxController.wipe();
              await _tixController.wipe();

              await _tixController.populate();
            },
            isEmpty: _pxController.isEmpty,
          ),
        ],
      ),
    );
  }
}

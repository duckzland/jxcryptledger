import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../app/exceptions.dart';
import '../../app/layout.dart';
import '../../core/runtime/locator.dart';
import '../../core/scrollto.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/state.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/dialogs/alert.dart';
import '../../widgets/dialogs/show_form.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/layouts/sliver_grid.dart';
import '../../widgets/notify.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../../widgets/separator.dart';
import '../cryptos/controller.dart';
import 'panels/model.dart';
import 'tickers/controller.dart';
import 'panels/controller.dart';
import 'panels/form.dart';
import 'panels/display.dart';
import 'tickers/display.dart';
import 'tickers/model.dart';

class WatchboardPage extends StatefulWidget {
  const WatchboardPage({super.key});

  @override
  State<WatchboardPage> createState() => _WatchboardPageState();
}

class _WatchboardPageState extends State<WatchboardPage> with MixinsState, MixinsActionBar<WatchboardPage> {
  late final PanelsController _pxController;
  late final TickersController _tixController;
  late final CryptosController _cryptosController;

  final scrollUtil = ScrollTo('px-offset');
  late List<PanelsModel> txs;
  late List<TickersModel> tickers;

  bool _enableDrag = false;
  bool _enableTickers = true;
  bool _hasLinked = false;

  DateTime _lastPress = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _pxController = locator<PanelsController>();
    _pxController.addListener(_onPanelsControllerChanged);

    _tixController = locator<TickersController>();
    _tixController.addListener(_onTickersControllerChanged);

    _cryptosController = locator<CryptosController>();
    _cryptosController.addListener(_onCryptosControllerChanged);

    _hasLinked = _pxController.hasLinked();

    _enableDrag = states.get('px-enable-drag', defaultValue: false);
    _enableTickers = states.get('px-enable-tickers', defaultValue: true);

    txs = _pxController.items;
    tickers = _tixController.items;

    actionbarRegister("Crypto Watchboard");
  }

  @override
  void dispose() {
    scrollUtil.dispose();

    _pxController.removeListener(_onPanelsControllerChanged);
    _tixController.removeListener(_onTickersControllerChanged);
    _cryptosController.removeListener(_onCryptosControllerChanged);

    super.dispose();
  }

  void _onCryptosControllerChanged() {
    if (mounted) {
      setState(() {});
      AppLayout.refreshBar?.call();
    }
  }

  void _onPanelsControllerChanged() {
    if (!mounted) return;
    final oldEmpty = txs.isEmpty;
    txs = _pxController.items;
    _hasLinked = _pxController.hasLinked();

    final nowEmpty = txs.isEmpty;
    if (oldEmpty != nowEmpty) {
      AppLayout.refreshBar?.call();
      setState(() {});
    }
  }

  void _onTickersControllerChanged() {
    if (!mounted) return;
    setState(() {
      tickers = _tixController.items;
    });
  }

  @override
  Widget actionbarLeftAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Wrap(
          spacing: 4,
          children: [
            WidgetsButtonsAction(
              key: _enableTickers ? const Key("ticker-shown") : const Key("ticker-hidden"),
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
                  AppLayout.refreshBar?.call();
                  states.set('px-enable-tickers', _enableTickers);
                });
              },
            ),
            WidgetsButtonsAction(
              key: _enableDrag ? const Key("panel-drag-allowed") : const Key("panel-drag-disabled"),
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

                  AppLayout.refreshBar?.call();

                  widgetsNotifyClear();
                  widgetsNotifySuccess(_enableDrag ? "Watchboard dragging enabled." : "Watchboard dragging disabled.");

                  states.set('px-enable-drag', _enableDrag);
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
        const WidgetsSeparator(),
        Wrap(
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
        const WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: const Key("import-button-batch"),
              tooltip: "Import watchboard to database",
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await _pxController.importDatabase(json);
                _pxController.scheduleRates();
                await _tixController.refreshRates();
                states.remove('px-offset');
              },
              evaluator: (s) {},
            ),
            WidgetsDialogsExport(
              key: const Key("export-button-batch"),
              tooltip: "Export watchboard from database",
              suggestedPrefix: "watchboards_",
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
                await _pxController.clear();
                await _tixController.wipe();

                await _tixController.populate();
                states.remove('px-offset');
              },
              isEmpty: _pxController.isEmpty,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cryptosController.isEmpty()) {
      actionbarRemove();
      return const WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding watchboard.');
    }

    if (_pxController.isEmpty()) {
      actionbarRemove();
      return WidgetsScreensEmpty(
        title: "Add Watchboard",
        addTitle: "Add New",
        addTooltip: "Create new watchboard entry",
        addEvaluator: () => !_cryptosController.isEmpty(),
        importTitle: "Import",
        importTooltip: "Import watchboard to database",
        importEvaluator: () => true,
        importCallback: (json) async {
          await _pxController.importDatabase(json);
          _pxController.scheduleRates();
          await _tixController.refreshRates();
          states.remove('px-offset');
        },
        addForm: _buildForm,
      );
    }

    actionbarRegister("Crypto Watchboard");
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            spacing: 12,
            children: [
              if (_enableTickers)
                Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(listenable: _tixController, builder: (_, _) => _buildTickers()),
                    ),
                  ],
                ),
              Flexible(
                flex: 10,
                fit: FlexFit.loose,
                child: ListenableBuilder(listenable: _pxController, builder: (_, _) => _buildPanels()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanels() {
    txs.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    return ReorderableGridView.builder(
      controller: scrollUtil.controller,
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: SliverGridDelegateWithMinWidth(
        minCrossAxisExtent: 320,
        itemHeight: 105,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        horizontalPadding: 12,
      ),
      dragEnabled: _enableDrag,
      dragStartDelay: const Duration(microseconds: 10),
      itemCount: txs.length,
      itemBuilder: (context, index) {
        final tx = txs[index];
        return PanelsDisplay(key: ValueKey(tx.tid), tix: tx, isDragging: _enableDrag);
      },
      dragWidgetBuilder: (index, child) {
        return Material(color: Colors.transparent, elevation: 0, child: child);
      },
      onReorder: (oldIndex, newIndex) {
        final moved = txs.removeAt(oldIndex);
        txs.insert(newIndex, moved);

        for (var i = 0; i < txs.length; i++) {
          txs[i].order = i;
        }
        _pxController.updateOrder(txs);
      },
    );
  }

  Widget _buildTickers() {
    final items = tickers.toList()..sort((a, b) => a.order.compareTo(b.order));

    return LayoutBuilder(
      builder: (context, constraints) {
        const baseWidth = 140.0;
        const spacing = 8.0;
        const totalTickers = 8;
        const itemHeight = 47.0;
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
          perRow = 2;
        }

        final rows = (totalTickers / perRow).ceil();
        final newWidth = (constraints.maxWidth / perRow) - spacing;
        final tickerHeight = itemHeight * rows + ((rows - 1) * spacing);

        return SizedBox(
          height: tickerHeight,
          child: ReorderableGridView.builder(
            gridDelegate: SliverGridDelegateWithMinWidth(
              minCrossAxisExtent: newWidth > 140 ? newWidth : 140,
              itemHeight: 47.0,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              horizontalPadding: 8,
            ),
            dragEnabled: _enableDrag,
            dragStartDelay: const Duration(microseconds: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tx = items[index];
              return TickersDisplay(key: ValueKey(tx.tid), tix: tx, isDragging: _enableDrag);
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
}

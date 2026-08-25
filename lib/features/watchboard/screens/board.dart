import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../app/content.dart';
import '../../../app/exceptions.dart';
import '../../../app/layout.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/action_bar.dart';
import '../../../mixins/state.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/buttons/dropdown.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../../widgets/dialogs/export.dart';
import '../../../widgets/dialogs/import.dart';
import '../../../widgets/dialogs/reset.dart';
import '../../../widgets/layouts/sliver_grid.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/screens/empty.dart';
import '../../../widgets/screens/fetch_cryptos.dart';
import '../../../widgets/separator.dart';
import '../../cryptos/controller.dart';
import '../panels/model.dart';
import '../tickers/controller.dart';
import '../panels/controller.dart';
import '../panels/form.dart';
import '../panels/display.dart';
import '../tickers/display.dart';
import '../tickers/model.dart';

class WatchboardScreensBoard extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensBoard({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensBoard> createState() => _WatchboardScreensBoardState();
}

class _WatchboardScreensBoardState extends State<WatchboardScreensBoard> with MixinsState, MixinsActionBar<WatchboardScreensBoard> {
  late final PanelsController _pxController;
  late final TickersController _tixController;
  late final CryptosController _cryptosController;

  final scrollUtil = ScrollTo('px-group-offset-board');
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
    _pxController = CoreLocator.getit<PanelsController>();
    _pxController.addListener(_onPanelsControllerChanged);

    _tixController = CoreLocator.getit<TickersController>();
    _tixController.addListener(_onTickersControllerChanged);

    _cryptosController = CoreLocator.getit<CryptosController>();
    _cryptosController.addListener(_onCryptosControllerChanged);

    _hasLinked = _pxController.hasLinked();

    _enableDrag = states.get('px-group-enable-drag', defaultValue: false);
    _enableTickers = states.get('px-group-enable-tickers', defaultValue: true);

    txs = [..._pxController.items];
    tickers = [..._tixController.items];

    txs.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    tickers.sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  void dispose() {
    scrollUtil.dispose();

    _pxController.removeListener(_onPanelsControllerChanged);
    _tixController.removeListener(_onTickersControllerChanged);
    _cryptosController.removeListener(_onCryptosControllerChanged);

    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
    List<Widget> navigation = [widget.screenNavigation];

    if (_cryptosController.isNotEmpty() && _pxController.isNotEmpty()) {
      navigation = [
        ...navigation,
        const WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsButtonsAction(
              key: _enableTickers ? const Key("ticker-shown") : const Key("ticker-hidden"),
              icon: Icons.remove_red_eye,
              padding: EdgeInsets.all(8),
              initialState: WidgetsButtonActionState.normal,
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: _enableTickers ? "Hide Watchboard Tickers" : "Show Watchboard Tickers",
              evaluator: _evaluatorTickerToggle,
              onPressed: _actionToggleTickers,
            ),
            WidgetsButtonsAction(
              key: _enableDrag ? const Key("panel-drag-allowed") : const Key("panel-drag-disabled"),
              icon: Icons.drag_indicator,
              padding: EdgeInsets.all(8),
              initialState: WidgetsButtonActionState.normal,
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: _enableDrag ? "Turn off watchboard dragging" : "Turn on watchboard dragging",
              evaluator: _evaluatorDragToggle,
              onPressed: _actionToggleDrag,
            ),
          ],
        ),
        const WidgetsSeparator(),
        WidgetsButtonsDropdown(
          maxVisible: 1,
          iconWidth: 34,
          iconHeight: 34,
          menuWidth: 130,
          menuAlignRight: true,
          listener: _pxController,
          dotEvaluator: (menuController) {
            return [
              WidgetsButtonActionState.action,
              if (_hasLinked) WidgetsButtonActionState.error,
              if (_hasLinked) WidgetsButtonActionState.primary,
              WidgetsButtonActionState.primary,
              WidgetsButtonActionState.action,
              WidgetsButtonActionState.error,
            ];
          },
          children: [
            WidgetsDialogsShowForm(
              key: const Key("add-button"),
              label: "Create New",
              tooltip: "Add new watchboard",
              buildForm: _buildForm,
              evaluator: (s) {
                if (_cryptosController.isEmpty()) {
                  s.disable();
                } else {
                  s.action();
                }
              },
            ),

            if (_hasLinked)
              WidgetsDialogsAlert(
                icon: Icons.delete_forever,
                initialState: WidgetsButtonActionState.error,
                label: "Delete Linked",
                tooltip: "Delete linked watchboard",
                dialogTitle: "Delete All Linked Watchboard",
                dialogMessage:
                    "This will delete all linked watchboard entry.\n"
                    "This action cannot be undone.",
                dialogConfirmLabel: "Delete",
                actionStartCallback: _actionWipeLinked,
                actionSuccessMessage: "All linked watchboard deleted.",
                actionErrorMessage: "Failed to delete linked watchboard.",
              ),

            if (_hasLinked)
              WidgetsDialogsAlert(
                icon: Icons.line_axis,
                initialState: WidgetsButtonActionState.primary,
                label: "Update Linked",
                tooltip: "Update linked watchboard",
                dialogTitle: "Update Linked Watchboard",
                dialogMessage:
                    "This will update all the linked watchboard.\n"
                    "This action cannot be undone.",
                dialogConfirmLabel: "Update",
                actionCompleteCallback: _actionUpdateLinked,
                actionErrorMessage: "Failed to update linked watchboard.",
              ),

            WidgetsDialogsImport(
              key: const Key("import-button-batch"),
              label: "Import DB",
              tooltip: "Import watchboard to database",
              showDialogBeforeImport: true,
              onImport: _actionImport,
            ),
            WidgetsDialogsExport(
              key: const Key("export-button-batch"),
              label: "Export DB",
              tooltip: "Export watchboard from database",
              suggestedPrefix: "watchboards_",
              onExport: _pxController.exportDatabase,
              isEmpty: _pxController.isEmpty,
            ),
            WidgetsDialogsReset(
              key: const Key("reset-button-batch"),
              label: "Reset DB",
              tooltip: "Reset watchboard database",
              dialogTitle: "Reset Watchboard Database",
              dialogMessage:
                  "This will delete all watchboard entries.\n"
                  "This action cannot be undone.",
              onWipe: _actionWipe,
              isEmpty: _pxController.isEmpty,
            ),
          ],
        ),
      ];
    }
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Watchboard");

    if (_cryptosController.isEmpty()) {
      return WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding watchboard.');
    }

    if (_pxController.isEmpty()) {
      return WidgetsScreensEmpty(
        title: "Add Watchboard",
        addTitle: "Add New",
        addTooltip: "Create new watchboard entry",
        addEvaluator: _cryptosController.isNotEmpty,
        importTitle: "Import",
        importTooltip: "Import watchboard to database",
        importEvaluator: () => true,
        importCallback: _actionImport,
        addForm: _buildForm,
      );
    }

    final tickersView = ListenableBuilder(listenable: _tixController, builder: (_, _) => _buildTickers());
    final panelsView = ListenableBuilder(listenable: _pxController, builder: (_, _) => _buildPanels());

    return AppContent(
      padding: EdgeInsets.only(left: 16, right: 16),
      spacing: 10,
      children: _enableTickers ? [tickersView, Flexible(flex: 10, fit: FlexFit.loose, child: panelsView)] : [panelsView],
    );
  }

  Widget _buildPanels() {
    return ReorderableGridView.builder(
      controller: scrollUtil.controller,
      padding: EdgeInsets.only(bottom: 12),
      gridDelegate: SliverGridDelegateWithMinWidth(
        minCrossAxisExtent: 320,
        itemHeight: 107,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        horizontalPadding: 10,
      ),
      dragEnabled: _enableDrag,
      dragStartDelay: Duration(microseconds: 10),
      itemCount: txs.length,
      itemBuilder: _panelItemBuilder,
      dragWidgetBuilder: _buildDragElement,
      onReorder: _panelActionDrag,
    );
  }

  Widget _buildTickers() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth = 140.0;
        final spacing = 6.0;
        final total = 16;
        final itemHeight = 49.0;

        final effectiveWidth = baseWidth + spacing;
        final maxPerRow = (constraints.maxWidth / effectiveWidth).floor().clamp(1, total);

        int perRow = 2;
        if (maxPerRow >= 8) {
          perRow = 8;
        } else if (maxPerRow >= 4) {
          perRow = 4;
        }

        int rows = (total / perRow).ceil();
        if (rows > 2) {
          rows = 2;
        }

        final newWidth = (constraints.maxWidth / perRow) - spacing;
        final height = itemHeight * rows + ((rows - 1) * spacing);

        return SizedBox(
          height: height,
          child: ReorderableGridView.builder(
            gridDelegate: SliverGridDelegateWithMinWidth(
              minCrossAxisExtent: newWidth > 140 ? newWidth : 140,
              itemHeight: 49.0,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              horizontalPadding: 6,
            ),
            dragEnabled: _enableDrag,
            dragStartDelay: Duration(microseconds: 10),
            itemCount: tickers.length,
            itemBuilder: _tickerItemBuilder,
            dragWidgetBuilder: _buildDragElement,
            onReorder: _tickerActionDrag,
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

  Widget _buildDragElement(int index, Widget child) {
    return Material(color: Colors.transparent, elevation: 0, child: child);
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
    txs = [..._pxController.items];
    txs.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

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
      tickers = [..._tixController.items];
      tickers.sort((a, b) => a.order.compareTo(b.order));
    });
  }

  void _evaluatorTickerToggle(WidgetsButtonsActionState s) {
    _enableTickers ? s.primary() : s.normal();
  }

  void _evaluatorDragToggle(WidgetsButtonsActionState s) {
    _enableDrag ? s.primary() : s.normal();
  }

  Future<void> _actionImport(String json) async {
    await _pxController.importDatabase(json);
    _pxController.scheduleRates();
    await _tixController.refreshRates();
    states.remove('px-group-offset-board');
    setState(() {});
  }

  Future<void> _actionWipe() async {
    await _pxController.clear();
    await _tixController.wipe();
    await _tixController.populate();
    states.remove('px-group-offset-board');
  }

  Future<void> _actionUpdateLinked() async {
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
  }

  Future<void> _actionWipeLinked() async {
    await _pxController.wipeLinked();
    setState(() {
      _hasLinked = false;
    });
  }

  void _actionToggleDrag(WidgetsButtonsActionState s) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
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

      states.set('px-group-enable-drag', _enableDrag);
    });
  }

  void _actionToggleTickers(WidgetsButtonsActionState s) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      setState(() {
        _enableTickers = !_enableTickers;
      });
      AppLayout.refreshBar?.call();
      states.set('px-group-enable-tickers', _enableTickers);
    });
  }

  Widget _panelItemBuilder(BuildContext context, int index) {
    final tx = txs[index];
    return PanelsDisplay(key: ValueKey(tx.tid), tix: tx, isDragging: _enableDrag);
  }

  void _panelActionDrag(int oldIndex, int newIndex) {
    setState(() {
      final moved = txs.removeAt(oldIndex);
      txs.insert(newIndex, moved);

      for (var i = 0; i < txs.length; i++) {
        txs[i].order = i;
      }
    });

    _pxController.updateOrder(txs);
  }

  Widget _tickerItemBuilder(BuildContext context, int index) {
    final tx = tickers[index];
    return TickersDisplay(key: ValueKey(tx.tid), tix: tx, isDragging: _enableDrag);
  }

  void _tickerActionDrag(int oldIndex, int newIndex) {
    setState(() {
      final moved = tickers.removeAt(oldIndex);
      tickers.insert(newIndex, moved);

      for (var i = 0; i < tickers.length; i++) {
        tickers[i].order = i;
      }
    });

    _tixController.updateOrder(tickers);
  }
}

import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/actionable.dart';
import '../../mixins/state.dart';
import '../../widgets/dialogs/show_form.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/button.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../../widgets/separator.dart';
import '../cryptos/controller.dart';
import 'controller.dart';
import 'dialogs/batch_action.dart';
import 'model.dart';
import 'forms/create.dart';
import 'screens/active.dart';
import 'screens/history.dart';
import 'screens/journal.dart';
import 'screens/overview.dart';

enum TransactionsViewMode { overview, active, journal, history }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => TransactionsPageState();
}

class TransactionsPageState extends State<TransactionsPage> with MixinsActionable, MixinsState, MixinsActionBar<TransactionsPage> {
  final CryptosController _cryptosController = locator<CryptosController>();

  late List<TransactionsModel> txs;
  late TransactionsController _txController;

  late Map<int, String> _sortableOptions;
  late Map<int, String> _filterableOptions;

  TransactionsViewMode _viewMode = TransactionsViewMode.active;

  int _sortMode = 0;
  int _filterMode = 0;

  @override
  void initState() {
    super.initState();

    _txController = locator<TransactionsController>();
    _txController.start();
    _txController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onCryptoControllerChanged);

    _viewMode = TransactionsViewMode.values.byName(states.get('tx-view-mode', defaultValue: "active"));

    txs = _txController.items;

    _detectFilterAndSortOptions();
    _setFilterAndSortDefault();

    actionbarRegister("Trading View");
  }

  @override
  void dispose() {
    _txController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onCryptoControllerChanged);

    super.dispose();
  }

  void _onCryptoControllerChanged() {
    setState(() {});
    AppLayout.refreshBar?.call();
  }

  void _onControllerChanged() {
    if (!_txController.isEqualToItems(txs)) {
      setState(() {
        txs = _txController.items;
      });
    }

    AppLayout.refreshBar?.call();
  }

  void _setFilterAndSortDefault() {
    switch (_viewMode) {
      case TransactionsViewMode.active:
        _sortMode = states.get('tx-sort-active', defaultValue: 2);
        _filterMode = states.get('tx-filter-active', defaultValue: 0);
        break;

      case TransactionsViewMode.overview:
        _sortMode = states.get('tx-sort-overview', defaultValue: 2);
        _filterMode = states.get('tx-filter-overview', defaultValue: 0);
        break;
      case TransactionsViewMode.journal:
        _sortMode = states.get('tx-sort-journal', defaultValue: 0);
        _filterMode = states.get('tx-filter-journal', defaultValue: 0);
        break;
      case TransactionsViewMode.history:
        _sortMode = states.get('tx-sort-history', defaultValue: 2);
        _filterMode = states.get('tx-filter-history', defaultValue: 0);
        break;
    }
  }

  void _detectFilterAndSortOptions() {
    _sortableOptions = {};
    _filterableOptions = {};
    switch (_viewMode) {
      case TransactionsViewMode.active:
        _sortableOptions = {0: "Alphabetically", 1: "Oldest Trades", 2: "Latest Trades"};
        _filterableOptions = {0: "Tradable Only", 1: "All Trades"};
        break;

      case TransactionsViewMode.overview:
        _sortableOptions = {0: "Alphabetically", 1: "Oldest Trades", 2: "Latest Trades"};
        _filterableOptions = {0: "Tradable Only", 1: "All Trades"};
        break;
      case TransactionsViewMode.journal:
        _sortableOptions = {};
        _filterableOptions = {
          0: "Show All",
          1: "Active Trades",
          2: "Partial Trades",
          3: "Inactive Trades",
          4: "Closed Trades",
          5: "Finalized Trades",
        };
        break;
      case TransactionsViewMode.history:
        _sortableOptions = {0: "Alphabetically", 1: "Oldest Trades", 2: "Latest Trades"};
        _filterableOptions = {};
        break;
    }
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
            WidgetsButton(
              icon: Icons.show_chart,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: "Active Trading",
              evaluator: (s) {
                if (_viewMode == TransactionsViewMode.active) {
                  s.active();
                } else {
                  s.normal();
                }
              },
              onPressed: (_) {
                setState(() {
                  _viewMode = TransactionsViewMode.active;
                  _setFilterAndSortDefault();
                  _detectFilterAndSortOptions();

                  states.set('tx-view-mode', TransactionsViewMode.active.name);
                });
              },
            ),
            WidgetsButton(
              icon: Icons.account_balance_wallet_outlined,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: "Balance Overview",
              evaluator: (s) {
                if (_viewMode == TransactionsViewMode.overview) {
                  s.active();
                } else {
                  s.normal();
                }
              },
              onPressed: (_) {
                setState(() {
                  _viewMode = TransactionsViewMode.overview;
                  _setFilterAndSortDefault();
                  _detectFilterAndSortOptions();

                  states.set('tx-view-mode', TransactionsViewMode.overview.name);
                });
              },
            ),
            WidgetsButton(
              icon: Icons.article_outlined,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: "Journal View",
              evaluator: (s) {
                if (_viewMode == TransactionsViewMode.journal) {
                  s.active();
                } else {
                  s.normal();
                }
              },
              onPressed: (_) {
                setState(() {
                  _viewMode = TransactionsViewMode.journal;
                  _setFilterAndSortDefault();
                  _detectFilterAndSortOptions();

                  states.set('tx-view-mode', TransactionsViewMode.journal.name);
                });
              },
            ),
            WidgetsButton(
              icon: Icons.history,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: "History View",
              evaluator: (s) {
                if (_viewMode == TransactionsViewMode.history) {
                  s.active();
                } else {
                  s.normal();
                }
              },
              onPressed: (_) {
                setState(() {
                  _viewMode = TransactionsViewMode.history;
                  _setFilterAndSortDefault();
                  _detectFilterAndSortOptions();

                  states.set('tx-view-mode', TransactionsViewMode.history.name);
                });
              },
            ),
          ],
        ),

        if (_sortableOptions.isNotEmpty || _filterableOptions.isNotEmpty) const WidgetsSeparator(),

        if (_sortableOptions.isNotEmpty || _filterableOptions.isNotEmpty)
          Wrap(spacing: 4, children: [if (_sortableOptions.isNotEmpty) _buildSorter(), if (_filterableOptions.isNotEmpty) _buildFilter()]),

        if (_viewMode == TransactionsViewMode.active ||
            _viewMode == TransactionsViewMode.overview ||
            _viewMode == TransactionsViewMode.history)
          const WidgetsSeparator(),

        if (_viewMode == TransactionsViewMode.active ||
            _viewMode == TransactionsViewMode.overview ||
            _viewMode == TransactionsViewMode.history)
          Wrap(
            spacing: 4,
            children: [
              WidgetsButton(
                key: const Key("toggle-hide-button"),
                icon: Icons.expand_less,
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                minimumSize: const Size(40, 40),
                tooltip: "Hide content",
                onPressed: (_) {
                  states.set("tx-toggle-panels", 'close');
                  setState(() {});
                },
              ),
              WidgetsButton(
                key: const Key("toggle-show-button"),
                icon: Icons.expand_more,
                padding: const EdgeInsets.all(0),
                iconSize: 18,
                minimumSize: const Size(40, 40),
                tooltip: "Show content",
                onPressed: (_) {
                  states.set("tx-toggle-panels", 'show');
                  setState(() {});
                },
              ),
            ],
          ),
        if (_viewMode == TransactionsViewMode.active ||
            _viewMode == TransactionsViewMode.overview ||
            _viewMode == TransactionsViewMode.history)
          const WidgetsSeparator(),

        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsShowForm(
              key: const Key("delete-multiple-button"),
              icon: Icons.delete,
              tooltip: "Delete all transactions",
              initialState: WidgetsButtonActionState.error,
              evaluator: (s) {
                final bool isDeletable = _txController.hasDeletableRoot();
                if (!isDeletable) {
                  s.disable();
                } else {
                  s.error();
                }
              },
              buildForm: (dialogContext) {
                return TransactionsDialogsBatchAction(
                  transactions: txs,
                  mode: TransactionsBatchActionMode.delete,
                  onSave: (e) => actionableFormSave<TransactionsModel>(
                    context,
                    dialogContext: dialogContext,
                    successMessage: "All transactions deleted.",
                    error: e,
                  ),
                );
              },
            ),
            WidgetsDialogsShowForm(
              key: const Key("close-multiple-button"),
              icon: Icons.close,
              tooltip: "Close all closable transactions",
              initialState: WidgetsButtonActionState.warning,
              evaluator: (s) {
                final bool isClosable = _txController.hasClosableLeaf();
                if (!isClosable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              buildForm: (dialogContext) {
                return TransactionsDialogsBatchAction(
                  transactions: txs,
                  mode: TransactionsBatchActionMode.close,
                  onSave: (e) => actionableFormSave<TransactionsModel>(
                    context,
                    dialogContext: dialogContext,
                    successMessage: "Transactions closed successfully.",
                    error: e,
                  ),
                );
              },
            ),
            WidgetsDialogsShowForm(
              key: const Key("finalize-multiple-button"),
              icon: Icons.close_fullscreen,
              tooltip: "Finalize all finalizable transactions",
              initialState: WidgetsButtonActionState.warning,
              evaluator: (s) {
                final bool isFinalizable = _txController.hasFinalizable();
                if (!isFinalizable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              buildForm: (dialogContext) {
                return TransactionsDialogsBatchAction(
                  transactions: txs,
                  mode: TransactionsBatchActionMode.finalize,
                  onSave: (e) => actionableFormSave<TransactionsModel>(
                    context,
                    dialogContext: dialogContext,
                    successMessage: "All transactions finalized.",
                    error: e,
                  ),
                );
              },
            ),

            WidgetsDialogsShowForm(
              key: const Key("add-button"),
              tooltip: "Add new transaction",
              buildForm: _buildForm,
              evaluator: (s) {
                if (_cryptosController.isEmpty()) {
                  s.disable();
                } else {
                  s.action();
                }
              },
            ),
          ],
        ),
        const WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: const Key("import-button-batch"),
              tooltip: "Import transactions to database",
              iconSize: 20,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await _txController.importDatabase(json);
                setState(() {});
                states.removeByPrefix('tx-group');
              },
            ),
            WidgetsDialogsExport(
              key: const Key("export-button-batch"),
              tooltip: "Export transactions from database",
              suggestedPrefix: "transactions_",
              onExport: _txController.exportDatabase,
              isEmpty: _txController.isEmpty,
            ),
            WidgetsDialogsReset(
              key: const Key("reset-button-batch"),
              tooltip: "Reset transactions database",
              dialogTitle: "Delete All Transactions",
              dialogMessage:
                  "This will delete all transactions and all of its history.\n"
                  "This action cannot be undone.",
              onWipe: () {
                states.removeByPrefix('tx-group');
                return _txController.wipe();
              },
              isEmpty: _txController.isEmpty,
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
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding transactions.')),
        ],
      );
    }

    if (txs.isEmpty) {
      actionbarRemove();
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: WidgetsScreensEmpty(
                    title: "Add Transaction",
                    addTitle: "Add New",
                    addTooltip: "Create new transaction entry",
                    addEvaluator: () => !_cryptosController.isEmpty(),
                    importTitle: "Import",
                    importTooltip: "Import transactions to database",
                    importEvaluator: () => true,
                    importCallback: (json) async => await _txController.importDatabase(json),
                    addForm: _buildForm,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1600), child: _buildScreen()),
    );
  }

  Widget _buildForm(BuildContext dialogContext) {
    return Center(
      child: TransactionFormCreate(
        onSave: (e, stx) =>
            actionableFormSave<TransactionsModel>(context, dialogContext: dialogContext, successMessage: "Transaction saved", error: e),
      ),
    );
  }

  Widget _buildSorter() {
    return Container(
      height: 38,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _sortMode,
          isExpanded: false,
          icon: const Icon(Icons.arrow_drop_down),
          style: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemHeight: kMinInteractiveDimension,
          items: _sortableOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sortMode = value);

            switch (_viewMode) {
              case TransactionsViewMode.active:
                states.set('tx-sort-active', value);
                break;

              case TransactionsViewMode.overview:
                states.set('tx-sort-overview', value);
                break;
              case TransactionsViewMode.journal:
                states.set('tx-sort-journal', value);
                break;
              case TransactionsViewMode.history:
                states.set('tx-sort-history', value);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      height: 38,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _filterableOptions.containsKey(_filterMode) ? _filterMode : _filterableOptions.keys.first,
          isExpanded: false,
          icon: const Icon(Icons.arrow_drop_down),
          style: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemHeight: kMinInteractiveDimension,
          items: _filterableOptions.entries.map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _filterMode = value);

            switch (_viewMode) {
              case TransactionsViewMode.active:
                states.set('tx-filter-active', value);
                break;

              case TransactionsViewMode.overview:
                states.set('tx-filter-overview', value);
                break;
              case TransactionsViewMode.journal:
                states.set('tx-filter-journal', value);
                break;
              case TransactionsViewMode.history:
                states.set('tx-filter-history', value);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case TransactionsViewMode.overview:
        actionbarRegister("Transaction Balance");
        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return TransactionsOverviewView(
          transactions: [...txs],
          panelsAction: toggleAction,
          filterMode: _filterMode,
          sortMode: _sortMode,
          onStatusChanged: () {},
        );

      case TransactionsViewMode.active:
        actionbarRegister("Trading View");
        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return TransactionsActiveView(
          transactions: [...txs],
          panelsAction: toggleAction,
          filterMode: _filterMode,
          sortMode: _sortMode,
          onStatusChanged: () {},
        );

      case TransactionsViewMode.journal:
        actionbarRegister("Transaction Overview");

        return TransactionsJournalView(filterMode: _filterMode, transactions: [...txs], onStatusChanged: () {});

      case TransactionsViewMode.history:
        actionbarRegister("Transaction History");

        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return TransactionHistory(sortMode: _sortMode, transactions: [...txs], panelsAction: toggleAction, onStatusChanged: () {});
    }
  }
}

import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../core/runtime/locator.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/actionable.dart';
import '../../mixins/state.dart';
import '../../widgets/buttons/dropdown.dart';
import '../../widgets/dialogs/show_form.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/screens/empty.dart';
import '../../widgets/screens/fetch_cryptos.dart';
import '../../widgets/separator.dart';
import '../cryptos/controller.dart';
import 'controller.dart';
import 'dialogs/batch_action.dart';
import 'mixins/flags.dart';
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

class TransactionsPageState extends State<TransactionsPage>
    with MixinsActionable, MixinsState, MixinsActionBar<TransactionsPage>, TransactionsMixinsFlags {
  final CryptosController _cryptosController = locator<CryptosController>();

  late Map<int, String> _sortableOptions;
  late Map<int, String> _filterableOptions;

  TransactionsViewMode _viewMode = TransactionsViewMode.active;

  int _sortMode = 0;
  int _filterMode = 0;

  @override
  void initState() {
    super.initState();

    txController = locator<TransactionsController>();
    txController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onCryptoControllerChanged);

    _viewMode = TransactionsViewMode.values.byName(states.get('tx-view-mode', defaultValue: "active"));

    txs = txController.items;
    fxs = {};
    fxsRebuild();

    _detectFilterAndSortOptions();
    _setFilterAndSortDefault();

    actionbarRegister("Trading View");
  }

  @override
  void dispose() {
    txController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onCryptoControllerChanged);
    super.dispose();
  }

  void _onCryptoControllerChanged() {
    setState(() {});
    AppLayout.refreshBar?.call();
  }

  void _onControllerChanged() {
    if (!txController.isEqualToItems(txs)) {
      setState(() {
        txs = txController.items;
        fxsRebuild();
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
            WidgetsButtonsAction(
              key: const Key("view-active"),
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
            WidgetsButtonsAction(
              key: const Key("view-balance"),
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
            WidgetsButtonsAction(
              key: const Key("view-journal"),
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
            WidgetsButtonsAction(
              key: const Key("view-history"),
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
              WidgetsButtonsAction(
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
              WidgetsButtonsAction(
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

        WidgetsButtonsDropdown(
          maxVisible: 1,
          iconWidth: 34,
          iconHeight: 34,
          menuWidth: 120,
          menuAlignRight: true,
          listener: txController,
          dotEvaluator: (menuController) {
            return [
              WidgetsButtonActionState.action,
              if (txController.hasDeletableRoot()) WidgetsButtonActionState.error,
              if (txController.hasClosableLeaf()) WidgetsButtonActionState.warning,
              if (txController.hasFinalizable()) WidgetsButtonActionState.warning,
              WidgetsButtonActionState.primary,
              WidgetsButtonActionState.action,
              WidgetsButtonActionState.error,
            ];
          },
          children: [
            WidgetsDialogsShowForm(
              key: const Key("add-button"),
              tooltip: "Add new transaction",
              label: "Create New",
              buildForm: _buildForm,
              evaluator: (s) {
                if (_cryptosController.isEmpty()) {
                  s.disable();
                } else {
                  s.action();
                }
              },
            ),

            if (txController.hasDeletableRoot())
              WidgetsDialogsShowForm(
                key: const Key("delete-multiple-button"),
                icon: Icons.delete,
                tooltip: "Delete all transactions",
                label: "Delete",
                initialState: WidgetsButtonActionState.error,
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

            if (txController.hasClosableLeaf())
              WidgetsDialogsShowForm(
                key: const Key("close-multiple-button"),
                icon: Icons.close,
                tooltip: "Close all closable transactions",
                label: "Close",
                initialState: WidgetsButtonActionState.warning,
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

            if (txController.hasFinalizable())
              WidgetsDialogsShowForm(
                key: const Key("finalize-multiple-button"),
                icon: Icons.close_fullscreen,
                tooltip: "Finalize all finalizable transactions",
                label: "Finalize",
                initialState: WidgetsButtonActionState.warning,
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

            WidgetsDialogsImport(
              key: const Key("import-button-batch"),
              tooltip: "Import transactions to database",
              label: "Import DB",
              iconSize: 20,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await txController.importDatabase(json);
                setState(() {});
                states.removeByPrefix('tx-group');
              },
            ),

            WidgetsDialogsExport(
              key: const Key("export-button-batch"),
              tooltip: "Export transactions from database",
              label: "Export DB",
              suggestedPrefix: "transactions_",
              onExport: txController.exportDatabase,
              isEmpty: txController.isEmpty,
            ),

            WidgetsDialogsReset(
              key: const Key("reset-button-batch"),
              tooltip: "Reset transactions database",
              label: "Reset DB",
              dialogTitle: "Delete All Transactions",
              dialogMessage:
                  "This will delete all transactions and all of its history.\n"
                  "This action cannot be undone.",
              onWipe: () {
                states.removeByPrefix('tx-group');
                return txController.wipe();
              },
              isEmpty: txController.isEmpty,
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
      return const WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding transactions.');
    }

    if (txs.isEmpty) {
      actionbarRemove();
      return WidgetsScreensEmpty(
        title: "Add Transaction",
        addTitle: "Add New",
        addTooltip: "Create new transaction entry",
        addEvaluator: () => !_cryptosController.isEmpty(),
        importTitle: "Import",
        importTooltip: "Import transactions to database",
        importEvaluator: () => true,
        importCallback: (json) async => await txController.importDatabase(json),
        addForm: _buildForm,
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
    return DropdownMenu<int>(
      initialSelection: _sortMode,
      alignmentOffset: const Offset(0, 3),
      requestFocusOnTap: false,
      inputDecorationTheme: Theme.of(
        context,
      ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38)),
      showTrailingIcon: false,
      dropdownMenuEntries: _sortableOptions.entries.map((e) {
        return DropdownMenuEntry<int>(value: e.key, label: e.value);
      }).toList(),
      onSelected: (value) {
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
    );
  }

  Widget _buildFilter() {
    return DropdownMenu<int>(
      initialSelection: _filterableOptions.containsKey(_filterMode) ? _filterMode : _filterableOptions.keys.first,
      requestFocusOnTap: false,
      alignmentOffset: const Offset(0, 3),
      showTrailingIcon: false,
      inputDecorationTheme: Theme.of(
        context,
      ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38)),
      dropdownMenuEntries: _filterableOptions.entries.map((e) {
        return DropdownMenuEntry<int>(value: e.key, label: e.value);
      }).toList(),
      onSelected: (value) {
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
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case TransactionsViewMode.overview:
        actionbarRegister("Transaction Balance");
        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: TransactionsOverviewView(
            transactions: txs,
            panelsAction: toggleAction,
            filterMode: _filterMode,
            sortMode: _sortMode,
            txsFlags: fxs,
            onStatusChanged: () {},
          ),
        );

      case TransactionsViewMode.active:
        actionbarRegister("Trading View");
        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: TransactionsActiveView(
            transactions: txs,
            panelsAction: toggleAction,
            filterMode: _filterMode,
            sortMode: _sortMode,
            txsFlags: fxs,
            onStatusChanged: () {},
          ),
        );

      case TransactionsViewMode.journal:
        actionbarRegister("Transaction Overview");

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: TransactionsJournalView(filterMode: _filterMode, transactions: txs, txsFlags: fxs, onStatusChanged: () {}),
        );

      case TransactionsViewMode.history:
        actionbarRegister("Transaction History");

        final toggleAction = states.get("tx-toggle-panels", defaultValue: "");
        states.remove("tx-toggle-panels");

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: TransactionHistory(
            sortMode: _sortMode,
            transactions: txs,
            txsFlags: fxs,
            panelsAction: toggleAction,
            onStatusChanged: () {},
          ),
        );
    }
  }
}

import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../core/scrollto.dart';
import '../../mixins/action_bar.dart';
import '../../mixins/actions.dart';
import '../../mixins/scrollto_group.dart';
import '../../widgets/dialogs/alert.dart';
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
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with MixinsActions, MixinsActionBar<TransactionsPage>, MixinsScrollToGroup<TransactionsPage, TransactionsModel> {
  final CryptosController _cryptosController = locator<CryptosController>();

  late List<TransactionsModel> txs;
  late TransactionsController _txController;

  late Map<int, String> _sortableOptions;
  late Map<int, String> _filterableOptions;

  TransactionsViewMode _viewMode = TransactionsViewMode.active;

  Map<String, List<TransactionsModel>> groups = {};

  int _sortMode = 0;
  int _filterMode = 0;
  int _txbuild = 0;

  @override
  final scrollUtil = ScrollTo();

  @override
  void initState() {
    super.initState();

    _txController = locator<TransactionsController>();
    _txController.start();
    _txController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onCryptoControllerChanged);

    txs = _txController.items;

    _detectFilterAndSortOptions();
    _setFilterAndSortDefault();

    registerBars("Trading View");
  }

  @override
  void dispose() {
    scrollUtil.dispose();

    _txController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onCryptoControllerChanged);

    super.dispose();
  }

  @override
  double scrollToGroupGetGroupHeight(List<TransactionsModel> txs, double currentWidth) {
    double height = 0.0;

    switch (_viewMode) {
      case TransactionsViewMode.overview:
        height += 16 + 20 + 16;
        height += (currentWidth > 560) ? 40 : 90;
        break;

      case TransactionsViewMode.active:
        height += 16 + 20 + 16;
        height += (currentWidth > 1000) ? 40 : 120;
        break;

      default:
        break;
    }

    height += (txs.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12;

    return height;
  }

  @override
  double scrollToGroupGetSeparatorHeight() {
    return 24;
  }

  void _onCryptoControllerChanged() {
    setState(() {});
    AppLayout.refreshBar?.call();
  }

  void _onControllerChanged() {
    if (!_txController.isEqualToItems(txs)) {
      setState(() {
        final tx = _txController.findNew(txs);
        txs = _txController.items;

        String key = "";
        Map<String, List<TransactionsModel>> oldGroups = groups;

        switch (_viewMode) {
          case TransactionsViewMode.overview:
            groups = _getOverviewTransactions();
            key = (tx != null) ? tx.rrId.toString() : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";
            break;

          case TransactionsViewMode.active:
            groups = _getActiveTransactions();
            key = (tx != null) ? "${tx.srId}-${tx.rrId}" : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";
            break;

          default:
            break;
        }
        if (key != "") {
          scrollToGroup(key, groups, context);
        }
      });
    }

    AppLayout.refreshBar?.call();
  }

  void _setFilterAndSortDefault() {
    switch (_viewMode) {
      case TransactionsViewMode.active:
        _sortMode = 2;
        _filterMode = 0;
        break;

      case TransactionsViewMode.overview:
        _sortMode = 2;
        _filterMode = 0;
        break;
      case TransactionsViewMode.journal:
        _sortMode = 0;
        _filterMode = 0;
        break;
      case TransactionsViewMode.history:
        _sortMode = 2;
        _filterMode = 0;
        break;
    }
  }

  void _detectFilterAndSortOptions() {
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

  Map<String, List<TransactionsModel>> _getOverviewTransactions() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = txs.where((t) => t.status == 1 || t.status == 2).toList();
        break;

      default:
        filtered = txs.toList();
    }

    final grouped = <String, List<TransactionsModel>>{};
    for (final tx in filtered) {
      grouped.putIfAbsent(tx.rrId.toString(), () => <TransactionsModel>[]);
      grouped[tx.rrId.toString()]!.add(tx);
    }

    final entries = grouped.entries.toList();

    switch (_sortMode) {
      case 0:
        entries.sort((a, b) {
          final symbolA = _cryptosController.getSymbol(int.parse(a.key)) ?? a.key;
          final symbolB = _cryptosController.getSymbol(int.parse(b.key)) ?? b.key;
          return symbolA.compareTo(symbolB);
        });
        break;

      case 1:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          return aDate.compareTo(bDate);
        });
        break;

      case 2:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return Map<String, List<TransactionsModel>>.fromEntries(entries);
  }

  Map<String, List<TransactionsModel>> _getActiveTransactions() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = txs.where((t) => t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index).toList();
        break;

      default:
        filtered = txs;
    }

    final grouped = <String, List<TransactionsModel>>{};
    for (final tx in filtered) {
      final pairKey = "${tx.srId}-${tx.rrId}";
      grouped.putIfAbsent(pairKey, () => []);
      grouped[pairKey]!.add(tx);
    }

    final entries = grouped.entries.toList();
    switch (_sortMode) {
      case 0:
        entries.sort((a, b) {
          final aParts = a.key.split('-');
          final bParts = b.key.split('-');

          final aSr = _cryptosController.getSymbol(int.parse(aParts[0])) ?? aParts[0];
          final bSr = _cryptosController.getSymbol(int.parse(bParts[0])) ?? bParts[0];
          return aSr.compareTo(bSr);
        });
        break;

      case 1:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          return aDate.compareTo(bDate);
        });
        break;

      case 2:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return Map<String, List<TransactionsModel>>.fromEntries(entries);
  }

  List<TransactionsModel> _getJournalTransactions() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 1:
        filtered = txs.where((t) => t.status == TransactionStatus.active.index).toList();
        break;

      case 2:
        filtered = txs.where((t) => t.status == TransactionStatus.partial.index).toList();
        break;

      case 3:
        filtered = txs.where((t) => t.status == TransactionStatus.inactive.index).toList();
        break;

      case 4:
        filtered = txs.where((t) => t.status == TransactionStatus.closed.index).toList();
        break;

      case 5:
        filtered = txs.where((t) => t.status == TransactionStatus.finalized.index).toList();
        break;

      default:
        filtered = txs;
    }

    return filtered;
  }

  List<TransactionsModel> _getHistoryTransactions() {
    switch (_sortMode) {
      case 0:
        return List<TransactionsModel>.from(txs)..sort((a, b) {
          final aSr = _cryptosController.getSymbol(a.srId) ?? a.srId.toString();
          final bSr = _cryptosController.getSymbol(b.srId) ?? b.srId.toString();
          return aSr.compareTo(bSr);
        });

      case 1:
        return List<TransactionsModel>.from(txs)..sort((a, b) => a.sanitizedTimestamp.compareTo(b.sanitizedTimestamp));

      default:
        return List<TransactionsModel>.from(txs)..sort((a, b) => b.sanitizedTimestamp.compareTo(a.sanitizedTimestamp));
    }
  }

  @override
  Widget buildLeftAction() {
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
                  _detectFilterAndSortOptions();
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
                  _detectFilterAndSortOptions();
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
                  _detectFilterAndSortOptions();
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
                  _detectFilterAndSortOptions();
                });
              },
            ),
          ],
        ),
        if (_sortableOptions.isNotEmpty || _filterableOptions.isNotEmpty) WidgetsSeparator(),
        if (_sortableOptions.isNotEmpty || _filterableOptions.isNotEmpty)
          Wrap(spacing: 4, children: [if (_sortableOptions.isNotEmpty) _buildSorter(), if (_filterableOptions.isNotEmpty) _buildFilter()]),
        WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsAlert(
              key: Key("delete-button-batch"),
              icon: Icons.delete,
              initialState: WidgetsButtonActionState.error,
              tooltip: "Remove deletable transactions",
              evaluator: (s) {
                final bool isDeletable = _txController.hasDeletableRoot();
                if (!isDeletable) {
                  s.disable();
                } else {
                  s.error();
                }
              },
              dialogTitle: "Delete All Transactions",
              dialogMessage:
                  "This will delete all transactions and all of its history.\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Delete",
              actionStartCallback: _txController.deleteAll,
              actionSuccessMessage: "All transactions deleted.",
              actionErrorMessage: "Failed to delete transactions.",
            ),
            WidgetsDialogsAlert(
              key: Key("close-button-batch"),
              icon: Icons.close,
              initialState: WidgetsButtonActionState.warning,
              tooltip: "Close all closable transactions",
              evaluator: (s) {
                final bool isClosable = _txController.hasClosableLeaf();
                if (!isClosable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              dialogTitle: "Close All Transactions",
              dialogMessage:
                  "Are you sure you want to close all closable transactions?\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Close",
              actionStartCallback: _txController.closeAll,
              actionSuccessMessage: "All transactions closed.",
              actionErrorMessage: "Failed to close transactions.",
            ),
            WidgetsDialogsAlert(
              key: Key("finalize-button-batch"),
              icon: Icons.close_fullscreen,
              initialState: WidgetsButtonActionState.warning,
              tooltip: "Finalize all finalizable transactions",
              evaluator: (s) {
                final bool isFinalizable = _txController.hasFinalizable();
                if (!isFinalizable) {
                  s.disable();
                } else {
                  s.warning();
                }
              },
              dialogTitle: "Finalize All Transactions",
              dialogMessage:
                  "Are you sure you want to finalize all finalizable transactions?\n"
                  "This action cannot be undone.",
              dialogConfirmLabel: "Finalize",
              actionStartCallback: _txController.finalizeAll,
              actionSuccessMessage: "All transactions finalized.",
              actionErrorMessage: "Failed to finalize transactions.",
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
        WidgetsSeparator(),
        Wrap(
          spacing: 4,
          children: [
            WidgetsDialogsImport(
              key: Key("import-button-batch"),
              tooltip: "Import transactions to database",
              iconSize: 20,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              showDialogBeforeImport: true,
              onImport: (String json) async {
                await _txController.importDatabase(json);
                setState(() {
                  _txbuild++;
                });
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
              onWipe: _txController.wipe,
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
      removeBars();
      return Column(
        children: [
          Expanded(child: WidgetsScreensFetchCryptos(description: 'You need to fetch the latest crypto list before adding transactions.')),
        ],
      );
    }

    if (txs.isEmpty) {
      removeBars();
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
            doFormSave<TransactionsModel>(context, dialogContext: dialogContext, successMessage: "Transaction saved", error: e),
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
          value: _filterMode,
          isExpanded: false,
          icon: const Icon(Icons.arrow_drop_down),
          style: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemHeight: kMinInteractiveDimension,
          items: _filterableOptions.entries.map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _filterMode = value);
          },
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case TransactionsViewMode.overview:
        registerBars("Transaction Balance");

        return _buildOverviewList(_getOverviewTransactions());

      case TransactionsViewMode.active:
        registerBars("Trading View");

        return _buildActiveTradingList(_getActiveTransactions());

      case TransactionsViewMode.journal:
        registerBars("Transaction Overview");

        return TransactionsJournalView(key: ValueKey(_txbuild), transactions: _getJournalTransactions(), onStatusChanged: () {});

      case TransactionsViewMode.history:
        registerBars("Transaction History");

        return TransactionHistory(key: ValueKey(_txbuild), sortMode: _sortMode, transactions: _getHistoryTransactions());
    }
  }

  Widget _buildOverviewList(Map<String, List<TransactionsModel>> grouped) {
    return ListView.separated(
      key: ValueKey(_txbuild),
      controller: scrollUtil.controller,
      padding: EdgeInsets.only(bottom: 24),
      itemCount: grouped.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, idx) {
        final rrId = grouped.keys.elementAt(idx);
        final txs = grouped[rrId]!;

        return TransactionsOverview(
          key: Key("$rrId-$_filterMode-$_sortMode"),
          id: int.parse(rrId),
          transactions: txs,
          onStatusChanged: () {},
        );
      },
    );
  }

  Widget _buildActiveTradingList(Map<String, List<TransactionsModel>> grouped) {
    return ListView.separated(
      key: ValueKey(_txbuild),
      controller: scrollUtil.controller,
      padding: EdgeInsets.only(bottom: 24),
      itemCount: grouped.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, idx) {
        final key = grouped.keys.elementAt(idx);
        final parts = key.split('-');

        final srId = int.parse(parts[0]);
        final rrId = int.parse(parts[1]);

        final txs = grouped[key]!;

        return TransactionsActive(
          key: Key("$srId-$rrId-$_filterMode-$_sortMode"),
          srid: srId,
          rrid: rrId,
          transactions: txs,
          onStatusChanged: () {},
        );
      },
    );
  }
}

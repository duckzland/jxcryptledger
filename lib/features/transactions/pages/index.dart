import 'package:flutter/material.dart';
import 'package:jxcryptledger/widgets/notify.dart';

import '../../../app/exceptions.dart';
import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/repository.dart';
import '../../cryptos/service.dart';
import '../controller.dart';
import '../form.dart';
import '../model.dart';
import '../screens/active.dart';
import '../screens/history.dart';
import '../screens/journal.dart';
import '../screens/overview.dart';

enum TransactionsViewMode { overview, active, journal, history }

class TransactionsPagesIndex extends StatefulWidget {
  const TransactionsPagesIndex({super.key});

  @override
  State<TransactionsPagesIndex> createState() => _TransactionsPagesIndexState();
}

class _TransactionsPagesIndexState extends State<TransactionsPagesIndex> {
  late TransactionsController _controller;
  late CryptosService _cryptosService;

  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

  TransactionsViewMode _viewMode = TransactionsViewMode.active;

  int _sortMode = 0;
  int _filterMode = 0;

  late Map<int, String> _sortableOptions;
  late Map<int, String> _filterableOptions;

  @override
  void initState() {
    super.initState();

    _controller = locator<TransactionsController>();
    _controller.load();
    _controller.addListener(_onControllerChanged);

    _cryptosService = locator<CryptosService>();
    _cryptosService.addListener(_onControllerChanged);

    _cryptosRepo.addListener(_onControllerChanged);

    _detectFilterAndSortOptions();
    _setFilterAndSortDefault();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _cryptosRepo.removeListener(_onControllerChanged);
    _cryptosService.removeListener(_onControllerChanged);

    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
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
        };
        break;
      case TransactionsViewMode.history:
        _sortableOptions = {0: "By Crypto ID", 1: "Oldest Trades", 2: "Latest Trades"};
        _filterableOptions = {};
        break;
    }
  }

  void _showAddTransactionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: TransactionForm(
            mode: TransactionsFormActionMode.addNew,
            onSave: (e) async {
              if (e == null) {
                Navigator.pop(dialogContext);
                widgetsNotifySuccess('Transaction saved');
                return;
              }

              if (e is ValidationException) {
                widgetsNotifyError(e.userMessage, ctx: context);
                return;
              }

              widgetsNotifyError(e.toString(), ctx: context);
            },
          ),
        ),
      ),
    );
  }

  void _changePageTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call(title);
    });
  }

  Map<int, List<TransactionsModel>> _getOverviewTransactions() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = _controller.items.where((t) => t.status == 1 || t.status == 2).toList();
        break;

      default:
        filtered = _controller.items.toList();
    }

    final grouped = <int, List<TransactionsModel>>{};
    for (final tx in filtered) {
      grouped.putIfAbsent(tx.rrId, () => <TransactionsModel>[]);
      grouped[tx.rrId]!.add(tx);
    }

    final entries = grouped.entries.toList();

    switch (_sortMode) {
      case 0:
        entries.sort((a, b) {
          final symbolA = _cryptosRepo.getSymbol(a.key) ?? a.key.toString();
          final symbolB = _cryptosRepo.getSymbol(b.key) ?? b.key.toString();
          return symbolA.compareTo(symbolB);
        });
        break;

      case 1:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x < y ? x : y);
          final bDate = b.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x < y ? x : y);
          return aDate.compareTo(bDate);
        });
        break;

      case 2:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x > y ? x : y);
          final bDate = b.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x > y ? x : y);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return Map<int, List<TransactionsModel>>.fromEntries(entries);
  }

  Map<String, List<TransactionsModel>> _getActiveTransactions() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = _controller.items
            .where((t) => t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index)
            .toList();
        break;

      default:
        filtered = _controller.items.toList();
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
        entries.sort((a, b) => a.key.compareTo(b.key));
        break;

      case 1:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x < y ? x : y);
          final bDate = b.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x < y ? x : y);
          return aDate.compareTo(bDate);
        });
        break;

      case 2:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x > y ? x : y);
          final bDate = b.value.map((tx) => tx.timestampAsMs).reduce((x, y) => x > y ? x : y);
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
        filtered = _controller.items.where((t) => t.status == TransactionStatus.active.index).toList();
        break;

      case 2:
        filtered = _controller.items.where((t) => t.status == TransactionStatus.partial.index).toList();
        break;

      case 3:
        filtered = _controller.items.where((t) => t.status == TransactionStatus.inactive.index).toList();
        break;

      case 4:
        filtered = _controller.items.where((t) => t.status == TransactionStatus.closed.index).toList();
        break;

      default:
        filtered = _controller.items;
    }

    return filtered;
  }

  List<TransactionsModel> _getHistoryTransactions() {
    switch (_sortMode) {
      case 0:
        return List<TransactionsModel>.from(_controller.items)..sort((a, b) => a.srId.compareTo(b.srId));

      case 1:
        return List<TransactionsModel>.from(_controller.items)
          ..sort((a, b) => a.timestampAsMs.compareTo(b.timestampAsMs));

      default:
        return List<TransactionsModel>.from(_controller.items)
          ..sort((a, b) => b.timestampAsMs.compareTo(a.timestampAsMs));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cryptosRepo.hasAny() && _controller.items.isEmpty) {
      return Column(children: [Expanded(child: _buildFetchCryptosState())]);
    }

    if (_controller.items.isEmpty) {
      return Column(children: [Expanded(child: _buildEmptyState())]);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: SizedBox()),
                _buildAction(),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 20,
                      children: [
                        if (_sortableOptions.isNotEmpty) _buildSorter(),
                        if (_filterableOptions.isNotEmpty) _buildFilter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildSorter() {
    return Container(
      height: 40,
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
      height: 40,
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
          items: _filterableOptions.entries
              .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _filterMode = value);
          },
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
          WidgetButton(
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
          WidgetButton(
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
          WidgetButton(
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
          WidgetButton(
            icon: Icons.add,
            padding: const EdgeInsets.all(8),
            initialState: WidgetsButtonActionState.action,
            iconSize: 20,
            minimumSize: const Size(40, 40),
            tooltip: "Add Transaction",
            onPressed: (_) => _showAddTransactionDialog(),
            evaluator: (s) {
              if (!_cryptosRepo.hasAny()) {
                s.disable();
              } else {
                s.action();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_viewMode) {
      case TransactionsViewMode.overview:
        _changePageTitle("Transaction Balance");

        return _buildOverviewList(_getOverviewTransactions());

      case TransactionsViewMode.active:
        _changePageTitle("Trading View");

        return _buildActiveTradingList(_getActiveTransactions());

      case TransactionsViewMode.journal:
        _changePageTitle("Transaction Overview");

        return TransactionsJournalView(
          transactions: List<TransactionsModel>.from(_getJournalTransactions()),
          onStatusChanged: () => setState(() {}),
        );

      case TransactionsViewMode.history:
        _changePageTitle("Transaction History");

        return TransactionHistory(transactions: _getHistoryTransactions());
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Add Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          WidgetButton(
            icon: Icons.add,
            initialState: WidgetsButtonActionState.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: (_) => _showAddTransactionDialog(),
            evaluator: (s) {
              if (!_cryptosRepo.hasAny()) {
                s.disable();
              } else {
                s.action();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFetchCryptosState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_download_outlined, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Cryptocurrency data not available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'You need to fetch the latest crypto list before adding transactions.',
            style: TextStyle(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          WidgetButton(
            icon: Icons.refresh,
            initialState: WidgetsButtonActionState.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: (s) async {
              s.progress();

              final success = await _cryptosService.fetch();

              if (!success) {
                s.error();
                if (mounted) {
                  widgetsNotifyError("Failed to fetch cryptocurrency data.");
                }
              } else {
                _cryptosRepo.getSymbolMap();
                s.action();
                if (mounted) {
                  widgetsNotifySuccess("Cryptocurrency list successfully retrieved.");
                  setState(() {});
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewList(Map<int, List<TransactionsModel>> grouped) {
    return ListView.separated(
      itemCount: grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, idx) {
        final rrId = grouped.keys.elementAt(idx);
        final txs = grouped[rrId]!;

        return TransactionsOverview(id: rrId, transactions: txs, onStatusChanged: () => setState(() {}));
      },
    );
  }

  Widget _buildActiveTradingList(Map<String, List<TransactionsModel>> grouped) {
    return ListView.separated(
      itemCount: grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, idx) {
        final key = grouped.keys.elementAt(idx);
        final parts = key.split('-');

        final srId = int.parse(parts[0]);
        final rrId = int.parse(parts[1]);

        final txs = grouped[key]!;

        return TransactionsActive(srid: srId, rrid: rrId, transactions: txs, onStatusChanged: () => setState(() {}));
      },
    );
  }
}

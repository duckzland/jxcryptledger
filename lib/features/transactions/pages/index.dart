import 'package:flutter/material.dart';
import 'package:jxcryptledger/widgets/notify.dart';

import '../../../core/locator.dart';
import '../../../widgets/button.dart';
import '../../cryptos/repository.dart';
import '../../cryptos/service.dart';
import '../controller.dart';
import '../form.dart';
import '../model.dart';
import '../screens/active.dart';
import '../screens/overview.dart';

enum TransactionsViewMode { balanceOverview, activeTrading }

class TransactionsPagesIndex extends StatefulWidget {
  const TransactionsPagesIndex({super.key});

  @override
  State<TransactionsPagesIndex> createState() => _TransactionsPagesIndexState();
}

class _TransactionsPagesIndexState extends State<TransactionsPagesIndex> {
  late TransactionsController _controller;
  late CryptosService _cryptosService;

  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

  TransactionsViewMode _viewMode = TransactionsViewMode.activeTrading;

  @override
  void initState() {
    super.initState();

    _controller = locator<TransactionsController>();
    _controller.load();
    _controller.addListener(_onControllerChanged);

    _cryptosService = locator<CryptosService>();
    _cryptosService.addListener(_onControllerChanged);

    _cryptosRepo.addListener(_onControllerChanged);
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

  void _showAddTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => TransactionForm(
        mode: TransactionsFormActionMode.addNew,
        onSave: () async {
          Navigator.pop(context);
          notifySuccess(context, 'Transaction saved');
        },
      ),
    );
  }

  Map<int, List<TransactionsModel>> _getBalanceOverviewTransactions() {
    final filtered = _controller.items.where((t) => t.status == 1 || t.status == 2).toList();

    final grouped = <int, List<TransactionsModel>>{};

    for (final tx in filtered) {
      grouped.putIfAbsent(tx.rrId, () => <TransactionsModel>[]);
      grouped[tx.rrId]!.add(tx);
    }

    final sortedGroups = Map<int, List<TransactionsModel>>.fromEntries(
      grouped.entries.toList()..sort((a, b) {
        final symbolA = _cryptosRepo.getSymbol(a.key) ?? a.key.toString();
        final symbolB = _cryptosRepo.getSymbol(b.key) ?? b.key.toString();
        return symbolA.compareTo(symbolB);
      }),
    );

    return sortedGroups;
  }

  Map<String, List<TransactionsModel>> _getActiveTransactions() {
    final filtered = _controller.items
        .where((t) => t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index)
        .toList();

    final grouped = <String, List<TransactionsModel>>{};

    for (final tx in filtered) {
      final pairKey = "${tx.srId}-${tx.rrId}";

      grouped.putIfAbsent(pairKey, () => []);
      grouped[pairKey]!.add(tx);
    }

    final sorted = Map<String, List<TransactionsModel>>.fromEntries(
      grouped.entries.toList()..sort((a, b) {
        final aSr = int.parse(a.key.split('-')[0]);
        final bSr = int.parse(b.key.split('-')[0]);
        return aSr.compareTo(bSr);
      }),
    );

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.items.isEmpty) {
      return Column(
        children: [
          _buildActionBar(),
          Expanded(child: !_cryptosRepo.hasAny() ? _buildFetchCryptosState() : _buildEmptyState()),
        ],
      );
    }

    return Column(
      children: [
        _buildActionBar(),
        const SizedBox(height: 16),
        Expanded(child: _buildListForViewMode()),
      ],
    );
  }

  Widget _buildListForViewMode() {
    switch (_viewMode) {
      case TransactionsViewMode.balanceOverview:
        final grouped = _getBalanceOverviewTransactions();
        return _buildOverviewList(grouped);

      case TransactionsViewMode.activeTrading:
        final grouped = _getActiveTransactions();
        return _buildActiveTradingList(grouped);
    }
  }

  Widget _buildActionBar() {
    return Wrap(
      spacing: 4,
      children: [
        WidgetButton(
          icon: Icons.account_balance_wallet_outlined,
          padding: const EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Balance Overview",
          evaluator: (s) {
            if (_viewMode == TransactionsViewMode.balanceOverview) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = TransactionsViewMode.balanceOverview;
            });
          },
        ),
        WidgetButton(
          icon: Icons.show_chart,
          padding: const EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Active Trading",
          evaluator: (s) {
            if (_viewMode == TransactionsViewMode.activeTrading) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = TransactionsViewMode.activeTrading;
            });
          },
        ),
        WidgetButton(
          icon: Icons.add,
          padding: const EdgeInsets.all(8),
          initialState: WidgetButtonActionState.action,
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
    );
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
            initialState: WidgetButtonActionState.action,
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
            initialState: WidgetButtonActionState.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: (s) async {
              s.progress();

              final success = await _cryptosService.fetch();

              if (!success) {
                s.error();
                if (mounted) {
                  notifyError(context, "Failed to fetch cryptocurrency data.");
                }
              } else {
                s.action();
                if (mounted) {
                  notifySuccess(context, "Cryptocurrency list successfully retrieved.");
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

import 'package:flutter/material.dart';

import '../../../../mixins/state.dart';
import '../model.dart';

mixin WatchboardMarketsMixinsFilterable<T extends StatefulWidget> on State<T>, MixinsState {
  int marketFilterableRank = 0;
  int marketFilterablePercent = 0;
  String get marketFilterableKey => "";

  void marketFilterableOnPriceFiltering(int value) {}
  void marketFilterableOnPercentFiltering(int value) {}

  @override
  void initState() {
    super.initState();
    marketFilterableRank = states.get("[np]-$marketFilterableKey-marketFilterable-rank", defaultValue: 0);
    marketFilterablePercent = states.get("[np]-$marketFilterableKey-marketFilterable-percent", defaultValue: 0);
  }

  Widget marketFilterableRankFilters() {
    return DropdownMenu<int>(
      key: Key("market-rank-filter"),
      initialSelection: marketFilterableRank,
      alignmentOffset: const Offset(0, 3),
      requestFocusOnTap: false,
      inputDecorationTheme: Theme.of(
        context,
      ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38)),
      showTrailingIcon: false,
      dropdownMenuEntries: [
        const DropdownMenuEntry<int>(value: 0, label: "Show All"),
        const DropdownMenuEntry<int>(value: 1, label: "Top 50"),
        const DropdownMenuEntry<int>(value: 2, label: "Top 100"),
        const DropdownMenuEntry<int>(value: 3, label: "Top 200"),
      ],
      onSelected: (value) {
        marketFilterableRank = value ?? 0;
        marketFilterableOnPriceFiltering(value ?? 0);
        states.set('[np]-$marketFilterableKey-marketFilterable-rank', value ?? 0);
      },
    );
  }

  Widget marketFilterablePercentFilters() {
    return DropdownMenu<int>(
      key: Key("market-percent-filter"),
      initialSelection: marketFilterablePercent,
      alignmentOffset: const Offset(0, 3),
      requestFocusOnTap: false,
      inputDecorationTheme: Theme.of(
        context,
      ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38, maxWidth: 60)),
      showTrailingIcon: false,
      dropdownMenuEntries: [
        const DropdownMenuEntry<int>(value: 0, label: "1h"),
        const DropdownMenuEntry<int>(value: 1, label: "24h"),
        const DropdownMenuEntry<int>(value: 2, label: "7d"),
        const DropdownMenuEntry<int>(value: 3, label: "30d"),
        const DropdownMenuEntry<int>(value: 4, label: "60d"),
        const DropdownMenuEntry<int>(value: 5, label: "90d"),
      ],
      onSelected: (value) {
        marketFilterablePercent = value ?? 0;
        marketFilterableOnPercentFiltering(value ?? 0);
        states.set('[np]-$marketFilterableKey-marketFilterable-percent', value ?? 0);
      },
    );
  }

  List<MarketsModel> marketFilterableFilter(List<MarketsModel> txs) {
    switch (marketFilterableRank) {
      case 1:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 50).toList();
        break;

      case 2:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 100).toList();
        break;

      case 3:
        txs = txs.where((tx) => tx.rank >= 101 && tx.rank <= 200).toList();
        break;

      default:
        break;
    }

    return txs;
  }

  double marketFilterableGetPercentageValue(MarketsModel tx) {
    switch (marketFilterablePercent) {
      case 0:
        return tx.percent1h ?? 0;

      case 1:
        return tx.percent24h ?? 0;

      case 2:
        return tx.percent7d ?? 0;

      case 3:
        return tx.percent30d ?? 0;

      case 4:
        return tx.percent60d ?? 0;

      case 5:
        return tx.percent90d ?? 0;

      default:
        return 0;
    }
  }

  String marketFilterableGetPercentageText(MarketsModel tx) {
    switch (marketFilterablePercent) {
      case 0:
        return tx.percent1hText;

      case 1:
        return tx.percent24hText;

      case 2:
        return tx.percent7dText;

      case 3:
        return tx.percent30dText;

      case 4:
        return tx.percent60dText;

      case 5:
        return tx.percent90dText;

      default:
        return "";
    }
  }
}

import 'package:flutter/material.dart';

import '../../../mixins/sortable_table.dart';
import '../model.dart';

mixin TransactionsMixinsSortableTable<T extends StatefulWidget> on State<T>, MixinsSortableTable<T> {
  @override
  String get sortableDefaultKey => "timestamp";

  @override
  void initState() {
    super.initState();

    sortableSorters = {
      "timestamp": (col, asc) => sortableOnSort(_sortByTimestamp, "timestamp", col, asc),

      "srAmount": (col, asc) => sortableOnSort(_sortBySrAmount, "srAmount", col, asc),

      "rrAmount": (col, asc) => sortableOnSort(_sortByRrAmount, "rrAmount", col, asc),

      "balance": (col, asc) => sortableOnSort(_sortByBalance, "balance", col, asc),

      "rate": (col, asc) => sortableOnSort(_sortByRate, "rate", col, asc),

      "status": (col, asc) => sortableOnSort(_sortByStatus, "status", col, asc),

      "current": (col, asc) => sortableOnSort(_sortByCurrent, "current", col, asc),

      "profit": (col, asc) => sortableOnSort(_sortByProfit, "profit", col, asc),

      "profitPercentage": (col, asc) => sortableOnSort(_sortByProfitPercentage, "profitPercentage", col, asc),

      "capital": (col, asc) => sortableOnSort(_sortByCapital, "capital", col, asc),
    };
  }

  int _sortByTimestamp(Map<String, dynamic> d) {
    if (!d.containsKey('tx')) return 0;
    final tx = d['tx'] as TransactionsModel?;
    return tx?.sanitizedTimestamp ?? 0;
  }

  (String, double) _sortBySrAmount(Map<String, dynamic> d) {
    final tx = d['tx'] as TransactionsModel?;
    if (tx == null) return ("", 0.0);

    final symbol = tx.isCapital ? "#" : (d.containsKey('_sourceSymbol') ? d['_sourceSymbol'] as String : "");

    final value = tx.srAmount.toDouble();

    return (symbol, value);
  }

  (String, double) _sortByRrAmount(Map<String, dynamic> d) {
    final tx = d['tx'] as TransactionsModel?;
    if (tx == null) return ("", 0.0);

    final symbol = tx.isCapital ? "#" : (d.containsKey('_resultSymbol') ? d['_resultSymbol'] as String : "");

    final value = tx.rrAmount.toDouble();

    return (symbol, value);
  }

  (String, double) _sortByBalance(Map<String, dynamic> d) {
    final tx = d['tx'] as TransactionsModel?;
    if (tx == null) return ("", 0.0);

    final symbol = tx.isCapital ? "#" : (d.containsKey('_resultSymbol') ? d['_resultSymbol'] as String : "");

    final value = tx.balance.toDouble();

    return (symbol, value);
  }

  (String, double) _sortByRate(Map<String, dynamic> d) {
    final tx = d['tx'] as TransactionsModel?;
    if (tx == null) return ("", 0.0);

    final symbol = tx.isCapital ? "#" : (d.containsKey('_resultSymbol') ? d['_resultSymbol'] as String : "##");

    final value = tx.isCapital ? tx.srAmount.toDouble() : tx.rate.toDouble();

    return (symbol, value);
  }

  String _sortByStatus(Map<String, dynamic> d) {
    if (!d.containsKey('tx')) return "";
    final tx = d['tx'] as TransactionsModel?;
    return tx?.statusText ?? "";
  }

  double _sortByCurrent(Map<String, dynamic> d) {
    if (!d.containsKey('_current')) return 0.0;
    return d['_current'] as double;
  }

  double _sortByProfit(Map<String, dynamic> d) {
    if (!d.containsKey('_profit')) return 0.0;
    return d['_profit'] as double;
  }

  double _sortByProfitPercentage(Map<String, dynamic> d) {
    if (!d.containsKey('_profitPercentage')) return 0.0;
    return d['_profitPercentage'] as double;
  }

  (String, double) _sortByCapital(Map<String, dynamic> d) {
    final symbol = d.containsKey('_capitalSymbol') ? d['_capitalSymbol'] as String : "";

    final used = d.containsKey('_capitalUsed') ? d['_capitalUsed'] as double : 0.0;

    return (symbol, used);
  }
}

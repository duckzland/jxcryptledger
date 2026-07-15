import 'package:flutter/material.dart';

import 'table.dart';

mixin MixinsSelectableTable<T extends StatefulWidget> on State<T>, MixinsTable {
  List<String> selectableSelectedRows = [];
  String get selectableKey => "";

  @override
  void initState() {
    super.initState();
    if (selectableKey.isNotEmpty) {
      final raw = states.get("[np]-$selectableKey-selected-rows", defaultValue: []) as List<dynamic>;
      selectableSelectedRows = raw.map((e) => e.toString()).toList();
    }
  }

  void selectableToggleSelected(String key) {
    if (selectableIsSelected(key)) {
      selectableSelectedRows.remove(key);
    } else {
      selectableSelectedRows.add(key);
    }

    if (selectableKey.isNotEmpty) {
      states.set("[np]-$selectableKey-selected-rows", selectableSelectedRows);
    }
  }

  void selectableSetSelected(String key, bool selected) {
    if (selected) {
      selectableSelectedRows.add(key);
    } else {
      selectableSelectedRows.remove(key);
    }
    if (selectableKey.isNotEmpty) {
      states.set("[np]-$selectableKey-selected-rows", selectableSelectedRows);
    }
  }

  bool selectableIsSelected(String key) {
    return selectableSelectedRows.contains(key);
  }

  bool selectableHasSelectedRows() {
    return selectableSelectedRows.isNotEmpty;
  }

  List<String> selectableGetSelectedRows() {
    return selectableSelectedRows;
  }
}

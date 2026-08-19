import 'package:flutter/material.dart';

import 'table.dart';

mixin MixinsSelectableTable<T extends StatefulWidget> on State<T>, MixinsTable {
  List<String> selectableSelectedRows = [];
  String get selectableKey => "";

  ValueNotifier<List<String>>? get selectableGroupRows => null;

  @override
  void initState() {
    super.initState();
    if (selectableKey.isNotEmpty) {
      final raw = states.get("[np]-$selectableKey-selected-rows", defaultValue: []) as List<dynamic>;
      selectableSelectedRows = raw.map((e) => e.toString()).toList();
      selectableGroupRows!.addListener(_selectableOnGroupChange);
      if (selectableGroupRows != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectableGroupRows != null) {
            selectableGroupRows!.value = [...selectableGroupRows!.value, ...selectableSelectedRows];
          }
        });
      }
    }
  }

  @override
  void dispose() {
    selectableGroupRows?.removeListener(_selectableOnGroupChange);
    super.dispose();
  }

  void _selectableOnGroupChange() {
    if (!mounted || selectableGroupRows == null) return;

    final groupItems = selectableGroupRows!.value;
    bool stateChanged = false;

    final updatedLocal = selectableSelectedRows.where((key) => groupItems.contains(key)).toList();

    if (updatedLocal.length != selectableSelectedRows.length) {
      selectableSelectedRows = updatedLocal;
      stateChanged = true;
    }

    if (stateChanged) {
      if (selectableKey.isNotEmpty) {
        states.set("[np]-$selectableKey-selected-rows", selectableSelectedRows);
      }
      setState(() {});
    }
  }

  void selectableToggleSelected(String key) {
    selectableSetSelected(key, !selectableIsSelected(key));
  }

  void selectableSetSelected(String key, bool selected) {
    if (selected) {
      selectableSelectedRows.add(key);
      if (selectableGroupRows != null) {
        selectableGroupRows!.value = [...selectableGroupRows!.value, key];
      }
    } else {
      selectableSelectedRows.remove(key);
      if (selectableGroupRows != null) {
        selectableGroupRows!.value = selectableGroupRows!.value.where((e) => e != key).toList();
      }
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

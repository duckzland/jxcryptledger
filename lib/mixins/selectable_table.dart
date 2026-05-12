mixin MixinsSelectableTable {
  List<String> selectableSelectedRows = [];

  void selectableToggleSelected(String key) {
    if (selectableIsSelected(key)) {
      selectableSelectedRows.remove(key);
    } else {
      selectableSelectedRows.add(key);
    }
  }

  void selectableSetSelected(String key, bool selected) {
    if (selected) {
      selectableSelectedRows.add(key);
    } else {
      selectableSelectedRows.remove(key);
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

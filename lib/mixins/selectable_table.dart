mixin MixinsSelectableTable {
  List<String> selectedRows = [];

  void toggleSelected(String key) {
    if (isSelected(key)) {
      selectedRows.remove(key);
    } else {
      selectedRows.add(key);
    }
  }

  void setSelected(String key, bool selected) {
    if (selected) {
      selectedRows.add(key);
    } else {
      selectedRows.remove(key);
    }
  }

  bool isSelected(String key) {
    return selectedRows.contains(key);
  }

  bool hasSelectedRows() {
    return selectedRows.isNotEmpty;
  }

  List<String> getSelectedRows() {
    return selectedRows;
  }
}

import 'package:flutter/material.dart';

mixin MixinsSortableTable<T extends StatefulWidget> on State<T> {
  late List<Map<String, dynamic>> rows;
  int sortColumnIndex = 0;
  bool sortAscending = false;

  void onSort<U>(U Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    setState(() {
      rows.sort((a, b) {
        final aField = getField(a);
        final bField = getField(b);

        if (aField is (String, num) && bField is (String, num)) {
          final c1 = aField.$1.compareTo(bField.$1);
          if (c1 != 0) return ascending ? c1 : -c1;

          final c2 = aField.$2.compareTo(bField.$2);
          return ascending ? c2 : -c2;
        }

        return ascending
            ? Comparable.compare(aField as Comparable, bField as Comparable)
            : Comparable.compare(bField as Comparable, aField as Comparable);
      });

      sortColumnIndex = columnIndex;
      sortAscending = ascending;
    });
  }
}

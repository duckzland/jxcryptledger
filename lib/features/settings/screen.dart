import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'controller.dart';
import 'model.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;

  @override
  void initState() {
    super.initState();

    columns = _buildColumns();
    rows = _buildRows(widget.controller.settings);

    widget.controller.addListener(() {
      setState(() {
        rows = _buildRows(widget.controller.settings);
      });
    });
  }

  List<PlutoColumn> _buildColumns() {
    return [
      PlutoColumn(title: 'Key', field: 'key', type: PlutoColumnType.text()),
      PlutoColumn(title: 'Value', field: 'value', type: PlutoColumnType.text()),
    ];
  }

  List<PlutoRow> _buildRows(SettingsModel? settings) {
    if (settings == null) return [];

    return settings.meta.entries.map((entry) {
      return PlutoRow(
        cells: {
          'key': PlutoCell(value: entry.key),
          'value': PlutoCell(value: entry.value.toString()),
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PlutoGrid(
      columns: columns,
      rows: rows,
      onLoaded: (event) {},
      onChanged: (event) {},
    );
  }
}

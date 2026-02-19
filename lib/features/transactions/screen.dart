import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'controller.dart';
import 'model.dart';

class TransactionsScreen extends StatefulWidget {
  final TransactionsController controller;

  const TransactionsScreen({super.key, required this.controller});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;

  @override
  void initState() {
    super.initState();

    columns = _buildColumns();
    rows = _buildRows(widget.controller.items);

    widget.controller.addListener(() {
      setState(() {
        rows = _buildRows(widget.controller.items);
      });
    });
  }

  List<PlutoColumn> _buildColumns() {
    return [
      //   PlutoColumn(title: 'TID', field: 'tid', type: PlutoColumnType.text()),
      //   PlutoColumn(title: 'RID', field: 'rid', type: PlutoColumnType.text()),
      //   PlutoColumn(title: 'PID', field: 'pid', type: PlutoColumnType.text()),
      PlutoColumn(
        title: 'SR Amount',
        field: 'srAmount',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        title: 'SR ID',
        field: 'srId',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        title: 'RR Amount',
        field: 'rrAmount',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        title: 'RR ID',
        field: 'rrId',
        type: PlutoColumnType.number(),
      ),
      //   PlutoColumn(
      //     title: 'Timestamp',
      //     field: 'timestamp',
      //     type: PlutoColumnType.number(),
      //   ),
    ];
  }

  List<PlutoRow> _buildRows(List<TransactionsModel> items) {
    return items.map((tx) {
      return PlutoRow(
        cells: {
          //   'tid': PlutoCell(value: tx.tid),
          //   'rid': PlutoCell(value: tx.rid),
          //   'pid': PlutoCell(value: tx.pid),
          'srAmount': PlutoCell(value: tx.srAmount),
          'srId': PlutoCell(value: tx.srId),
          'rrAmount': PlutoCell(value: tx.rrAmount),
          'rrId': PlutoCell(value: tx.rrId),
          //   'timestamp': PlutoCell(value: tx.timestamp),
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

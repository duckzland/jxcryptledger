import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../widgets/header.dart';
import '../../../../widgets/layouts/wrapped_two_columns.dart';
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../model.dart';
import '../../controller.dart';

class TransactionsWidgetsCardsSimpleTree extends StatefulWidget {
  final TransactionsModel tx;
  final IndexedTreeNode<TransactionsModel> node;
  final bool isActive;

  const TransactionsWidgetsCardsSimpleTree({super.key, required this.tx, required this.node, required this.isActive});

  @override
  State<TransactionsWidgetsCardsSimpleTree> createState() => _TransactionsWidgetsCardsSimpleTreeState();
}

class _TransactionsWidgetsCardsSimpleTreeState extends State<TransactionsWidgetsCardsSimpleTree> {
  CryptosController get _cryptosController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  late TransactionsModel _tx;

  Color _bgColor = AppTheme.tableRowBg;
  Color _fgColor = AppTheme.text;

  bool get isCapital => (widget.tx.isCapital);

  @override
  void initState() {
    super.initState();

    _tx = widget.tx;

    _calculateColor();
  }

  @override
  void didUpdateWidget(covariant TransactionsWidgetsCardsSimpleTree oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (_txController.isBothEqual(oldWidget.tx, widget.tx)) {
      return;
    }

    setState(() {
      _tx = widget.tx;
      _calculateColor();
    });
  }

  void _calculateColor() {
    switch (_tx.statusEnum) {
      case TransactionStatus.inactive:
        _bgColor = AppTheme.treeBgInactive;
        _fgColor = AppTheme.treeFgInactive;
        break;

      case TransactionStatus.closed:
        _bgColor = AppTheme.treeBgClosed;
        _fgColor = AppTheme.treeFgClosed;
        break;

      case TransactionStatus.finalized:
        _bgColor = AppTheme.treeBgFinalized;
        _fgColor = AppTheme.treeFgFinalized;
        break;

      default:
        _bgColor = AppTheme.treeBgNormal;
        _fgColor = AppTheme.treeFgNormal;
    }

    if (widget.isActive) {
      _bgColor = AppTheme.treeBgCurrent;
      _fgColor = AppTheme.treeFgCurrent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
      color: _bgColor,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 4),
        child: CustomMultiChildLayout(
          key: ValueKey(_tx.statusEnum),
          delegate: WidgetsLayoutsWrappedTwoColumns(onWrapChanged: (int totalRows, double currentHeight) {}, currentHeight: 37),
          children: [LayoutId(id: 'left', child: _buildCard())],
        ),
      ),
    );
  }

  Widget _buildCard() {
    bool showAvailable = _tx.balance > 0;

    final srSymbol = _cryptosController.getSymbol(_tx.srId) ?? '';
    final rrSymbol = _cryptosController.getSymbol(_tx.rrId) ?? '';

    final controller = ScrollController();
    double dragStartX = 0.0;
    double scrollStartX = 0.0;

    final header = WidgetsHeader(
      titleColor: _fgColor,
      title: _tx.isCapital ? "${_tx.srAmountText} $srSymbol" : "${_tx.srAmountText} → ${_tx.rrAmountText}",
      subtitle: _tx.isCapital ? "${_tx.timestampAsFormattedDate} | Capital" : "${_tx.timestampAsFormattedDate} | $srSymbol - $rrSymbol",
      reversed: true,
    );

    return Listener(
      onPointerDown: (event) {
        dragStartX = event.position.dx;
        scrollStartX = controller.offset;
      },
      onPointerMove: (event) {
        final delta = dragStartX - event.position.dx;
        final newOffset = (scrollStartX + delta).clamp(0.0, controller.position.maxScrollExtent);
        controller.jumpTo(newOffset);
      },
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          spacing: 20,
          mainAxisSize: MainAxisSize.max,
          children: [
            WidgetsWithTooltip(header, _tx.noteText),

            WidgetsHeader(titleColor: _fgColor, title: _tx.statusText, subtitle: "Status", reversed: true),

            if (showAvailable) WidgetsHeader(titleColor: _fgColor, title: _tx.balanceText, subtitle: "Avail. $rrSymbol", reversed: true),
          ],
        ),
      ),
    );
  }
}

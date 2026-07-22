import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/accent_colors.dart';
import '../../../widgets/fields/datepicker.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/header.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionFormTrade extends StatefulWidget {
  final void Function(Object? error, TransactionsModel? tx)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormTrade({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormTrade> createState() => _TransactionFormTradeState();
}

class _TransactionFormTradeState extends State<TransactionFormTrade> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;
  String? _parentNote;
  String? _groupNote;
  Color? _accentColor;

  final _formKey = GlobalKey<FormState>();

  bool get isRoot {
    final tx = widget.initialData;
    return tx != null && tx.isRoot;
  }

  bool get isLeaf => !isRoot;
  bool get isActive => widget.initialData?.statusEnum == TransactionStatus.active;

  String generateTid() => _txController.generateId();

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null && widget.initialData!.isRoot) {
      _parentNote = widget.initialData!.meta['purchase_notes'];
    }

    if (widget.initialData != null && widget.initialData!.isLeaf) {
      _parentNote = widget.initialData!.meta['trading_notes'];
    }

    if (widget.initialData != null) {
      _groupNote = widget.initialData!.meta['group_notes'];
    }

    _selectedRrId = null;
    _selectedDate = DateTime.now();
    _srAmount = null;
    _rrAmount = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1600),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 30,
              children: [
                _buildTitle(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Column(
                        spacing: 30,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [
                              SizedBox(width: 260, child: _buildDatePanel()),

                              Expanded(child: _buildFromPanel()),

                              Column(children: const [SizedBox(height: 42), Icon(Icons.arrow_forward, size: 24)]),

                              Expanded(child: _buildToPanel()),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [
                              Flexible(flex: 2, child: _buildNotesPanel()),
                              Flexible(flex: 2, child: _buildAccentColorsPanel()),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        spacing: 30,
                        children: [_buildDatePanel(), _buildFromPanel(), _buildToPanel(), _buildAccentColorsPanel(), _buildNotesPanel()],
                      );
                    }
                  },
                ),
                _buildButtonPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePanel() {
    return WidgetsHeader(subtitle: "On Date:", subtitleFontSize: 13, spacing: 10, child: _buildTimestampField());
  }

  Widget _buildFromPanel() {
    return WidgetsHeader(
      subtitle: "From:",
      subtitleFontSize: 13,
      spacing: 10,
      child: Row(spacing: 12, children: [Flexible(flex: 3, child: _buildSourceAmountField())]),
    );
  }

  Widget _buildToPanel() {
    return WidgetsHeader(
      subtitle: "To:",
      subtitleFontSize: 13,
      spacing: 10,
      child: Row(
        spacing: 12,
        children: [
          Flexible(flex: 2, child: _buildResultAmountField()),
          Flexible(flex: 2, child: _buildResultCryptoField()),
        ],
      ),
    );
  }

  Widget _buildNotesPanel() {
    return WidgetsHeader(subtitle: "Notes:", subtitleFontSize: 13, spacing: 10, child: _buildNotesField());
  }

  Widget _buildAccentColorsPanel() {
    return WidgetsHeader(subtitle: "Accent Color:", subtitleFontSize: 13, spacing: 10, child: _buildColorsField());
  }

  Widget _buildButtonPanel() {
    return _buildButtons();
  }

  Widget _buildTitle() {
    return const Text('Trade Crypto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    final data = widget.initialData;
    final balance = data?.balance ?? 0.0;
    final rrid = data?.rrId ?? 0;
    final symbol = _cryptoController.getSymbol(rrid);

    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'Max: ${Utils.formatSmartDouble(balance, smartDecimal: false)}',
      useMax: balance,
      suffixText: symbol,
      onChanged: (value) {
        _srAmount = value;
      },
    );
  }

  Widget _buildResultAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 10.5',
      onChanged: (value) {
        _rrAmount = value;
      },
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: _selectedRrId,
      onSelected: (id) => setState(() => _selectedRrId = id),
    );
  }

  Widget _buildNotesField() {
    const divider = Divider(height: 1, thickness: 1);
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_parentNote != null && _parentNote!.isNotEmpty) ...[Text(_parentNote!), divider],

        if (_groupNote != null && _groupNote!.isNotEmpty) ...[Text(_groupNote!), divider],

        WidgetsFieldsTextarea(
          title: 'New Trading Notes',
          helperText: 'Add trade-specific notes...',
          onChanged: (value) {
            setState(() => _noteEntry = value);
          },
        ),
      ],
    );
  }

  Widget _buildColorsField() {
    return WidgetsFieldsAccentColors(
      onChange: (value) {
        setState(() => _accentColor = value);
      },
    );
  }

  Widget _buildTimestampField() {
    TransactionsModel tx = widget.initialData!;

    final DateTime localParent = DateTime.fromMicrosecondsSinceEpoch(tx.sanitizedTimestamp, isUtc: true).toLocal();
    final DateTime firstDate = DateTime(localParent.year, localParent.month, localParent.day);

    return WidgetsFieldsDatepicker(
      labelText: 'Date',
      initialDate: DateTime.now(),
      firstDate: firstDate,
      lastDate: DateTime.now(),
      onSelected: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Wrap(
        direction: Axis.horizontal,
        runSpacing: 20,
        spacing: 10,
        runAlignment: WrapAlignment.center,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          WidgetsButtonsAction(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
          WidgetsButtonsAction(label: "Trade", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
        ],
      ),
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final parent = widget.initialData!;
    try {
      final child = TransactionsModel(
        tid: generateTid(),
        rid: _saveRidField(),
        pid: parent.tid,
        srId: parent.rrId,
        srAmount: _srAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_srAmount!)) ?? 0,
        rrId: _selectedRrId ?? 0,
        rrAmount: _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0,
        balance: _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0,
        status: TransactionStatus.active.index,
        timestamp: Utils.dateToTimestamp(_selectedDate),
        closable: false,
        meta: _saveMetaField(),
      );
      await _txController.add(child);
      widget.onSave?.call(null, child);
    } on ValidationException catch (e) {
      widget.onSave?.call(e, null);
    } catch (e) {
      widget.onSave?.call(e, null);
    }
  }

  String _saveRidField() {
    final data = widget.initialData!;
    if (data.isRoot) {
      return data.tid;
    }
    return data.rid;
  }

  Map<String, dynamic> _saveMetaField() {
    final data = widget.initialData!;
    final meta = Map<String, dynamic>.from(data.meta);

    meta['trading_notes'] = _noteEntry;

    if (_accentColor != null) {
      meta['accent_color'] = _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0');
    }
    return meta;
  }
}

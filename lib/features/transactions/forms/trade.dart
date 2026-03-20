import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/datepicker.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionFormTrade extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormTrade({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormTrade> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionFormTrade> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;
  String? _parentNote;

  final _formKey = GlobalKey<FormState>();

  bool get isRoot {
    final tx = widget.initialData;
    return tx != null && tx.isRoot;
  }

  bool get isLeaf => !isRoot;
  bool get isActive => widget.initialData?.statusEnum == TransactionStatus.active;

  String generateTid() => _txController.generateTid();

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null && widget.initialData!.isRoot) {
      _parentNote = widget.initialData!.meta['purchase_notes'];
    }

    if (widget.initialData != null && widget.initialData!.isLeaf) {
      _parentNote = widget.initialData!.meta['trading_notes'];
    }

    _selectedRrId = null;
    _selectedDate = DateTime.now();
    _srAmount = null;
    _rrAmount = null;
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
        meta: _saveNotesField(),
      );
      await _txController.add(child);
      widget.onSave?.call(null);
    } on ValidationException catch (e) {
      // TODO: Improve this by analyzing the error code and set the form field error state!
      widget.onSave?.call(e);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  String _saveRidField() {
    final data = widget.initialData!;
    if (data.isRoot) {
      return data.tid;
    }
    return data.rid;
  }

  Map<String, dynamic> _saveNotesField() {
    final data = widget.initialData!;
    final meta = Map<String, dynamic>.from(data.meta);

    meta['trading_notes'] = _noteEntry;
    return meta;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  _buildTitle(),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 16,
                          children: [
                            SizedBox(width: 260, child: _buildDatePanel()),

                            Expanded(child: _buildFromPanel()),

                            Column(children: const [SizedBox(height: 48), Icon(Icons.arrow_forward, size: 24)]),

                            Expanded(child: _buildToPanel()),
                          ],
                        );
                      } else {
                        return Column(spacing: 20, children: [_buildDatePanel(), _buildFromPanel(), _buildToPanel()]);
                      }
                    },
                  ),
                  _buildNotesPanel(),
                  _buildButtonPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 20),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("On date:", style: TextStyle(fontWeight: FontWeight.w600)),
          _buildTimestampField(),
        ],
      ),
    );
  }

  Widget _buildFromPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 20),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("From:", style: TextStyle(fontWeight: FontWeight.w600)),
          Row(spacing: 12, children: [Flexible(flex: 3, child: _buildSourceAmountField())]),
        ],
      ),
    );
  }

  Widget _buildToPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 20),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("To:", style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            spacing: 12,
            children: [
              Flexible(flex: 3, child: _buildResultAmountField()),
              Flexible(flex: 2, child: _buildResultCryptoField()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 20),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Notes:", style: TextStyle(fontWeight: FontWeight.w600)),
          _buildNotesField(),
        ],
      ),
    );
  }

  Widget _buildButtonPanel() {
    return WidgetsPanel(padding: const EdgeInsets.all(12), child: _buildButtons());
  }

  Widget _buildTitle() {
    return Text('Trade Crypto', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    final data = widget.initialData;
    final balance = data?.balance ?? 0.0;
    final rrid = data?.rrId ?? 0;
    final symbol = _cryptoController.getSymbol(rrid);

    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'Max: ${Utils.formatSmartDouble(balance)}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_parentNote != null && _parentNote != "") Text(_parentNote!),
        if (_parentNote != null && _parentNote != "") const SizedBox(height: 24),

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetsButton(label: "Trade", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

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
import '../controller.dart';
import '../model.dart';

class TransactionFormCreate extends StatefulWidget {
  final void Function(Object? error, TransactionsModel? tx)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormCreate({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormCreate> createState() => _TransactionFormCreateState();
}

class _TransactionFormCreateState extends State<TransactionFormCreate> {
  TransactionsController get _txController => locator<TransactionsController>();

  bool _isCapital = false;
  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;

  final _formKey = GlobalKey<FormState>();

  String generateTid() => _txController.generateId();

  @override
  void initState() {
    super.initState();

    _selectedSrId = null;
    _selectedRrId = null;
    _selectedDate = DateTime.now();
    _srAmount = null;
    _rrAmount = null;
    _noteEntry = null;
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCapital) {
      _rrAmount = _srAmount;
      _selectedRrId = _selectedSrId;
    }

    try {
      final tx = TransactionsModel(
        tid: generateTid(),
        rid: '0',
        pid: '0',
        srId: _selectedSrId ?? 0,
        srAmount: _srAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_srAmount!)) ?? 0,
        rrId: _selectedRrId ?? 0,
        rrAmount: _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0,
        balance: _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0,
        status: TransactionStatus.active.index,
        timestamp: Utils.dateToTimestamp(_selectedDate),
        closable: true,
        meta: {'purchase_notes': _noteEntry},
      );

      await _txController.add(tx);
      widget.onSave?.call(null, tx);
    } on ValidationException catch (e) {
      widget.onSave?.call(e, null);
    } catch (e) {
      widget.onSave?.call(e, null);
    }
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

                            if (!_isCapital) Column(children: const [SizedBox(height: 48), Icon(Icons.arrow_forward, size: 24)]),
                            if (!_isCapital) Expanded(child: _buildToPanel()),
                          ],
                        );
                      } else {
                        return Column(spacing: 20, children: [_buildDatePanel(), _buildFromPanel(), if (!_isCapital) _buildToPanel()]);
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("From:", style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                height: 20,
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _isCapital,
                  onChanged: (v) => setState(() => _isCapital = v!),
                ),
              ),
              const Text("Set as capital"),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              Flexible(flex: 3, child: _buildSourceAmountField()),
              Flexible(flex: 2, child: _buildSourceCryptoField()),
            ],
          ),
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
    return Text('New Transaction', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 1.5',
      onChanged: (value) {
        _srAmount = value;
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => _selectedSrId = id));
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
    return WidgetsFieldsCryptoSearch(labelText: 'Coin', initialValue: null, onSelected: (id) => setState(() => _selectedRrId = id));
  }

  Widget _buildNotesField() {
    return WidgetsFieldsTextarea(
      title: 'Purchase Notes',
      helperText: 'Add notes..',
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildTimestampField() {
    final currentDate = DateTime.now();

    return WidgetsFieldsDatepicker(
      labelText: 'Date',
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: currentDate,
      onSelected: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildButtons() {
    return Wrap(
      direction: Axis.horizontal,
      runSpacing: 20,
      spacing: 10,
      runAlignment: WrapAlignment.center,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        WidgetsButton(label: "Create New", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

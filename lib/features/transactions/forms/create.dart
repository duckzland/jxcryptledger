import 'package:flutter/material.dart';

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
  final void Function(Object? error)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormCreate({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormCreate> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionFormCreate> {
  TransactionsController get _txController => locator<TransactionsController>();

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;

  final _formKey = GlobalKey<FormState>();

  String generateTid() => _txController.generateTid();

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

    try {
      await _txController.add(tx);
      widget.onSave?.call(null);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTitle(),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 260,
                          child: WidgetsPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("On date:", style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                _buildTimestampField(),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: WidgetsPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("From:", style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Flexible(flex: 3, child: _buildSourceAmountField()),
                                    const SizedBox(width: 12),
                                    Flexible(flex: 2, child: _buildSourceCryptoField()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(children: const [SizedBox(height: 48), Icon(Icons.arrow_forward, size: 24)]),
                        const SizedBox(width: 16),
                        Expanded(
                          child: WidgetsPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("To:", style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Flexible(flex: 3, child: _buildResultAmountField()),
                                    const SizedBox(width: 12),
                                    Flexible(flex: 2, child: _buildResultCryptoField()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    WidgetsPanel(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Notes:", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 24),
                          _buildNotesField(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    WidgetsPanel(padding: const EdgeInsets.all(12), child: _buildButtons()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetButton(label: "Create New", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

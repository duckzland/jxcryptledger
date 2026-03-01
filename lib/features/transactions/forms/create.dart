import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../cryptos/search_field.dart';
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
  late CryptosController _cryptosController;

  TransactionsController get _txController => locator<TransactionsController>();

  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;

  final _formKey = GlobalKey<FormState>();

  String generateTid() => _txController.generateTid();

  @override
  void initState() {
    super.initState();
    _cryptosController = locator<CryptosController>();

    _srAmountController = TextEditingController();
    _rrAmountController = TextEditingController();
    _purchaseNotesController = TextEditingController();

    _selectedSrId = null;
    _selectedRrId = null;
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _srAmountController.dispose();
    _rrAmountController.dispose();
    _purchaseNotesController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final tx = TransactionsModel(
      tid: generateTid(),
      rid: '0',
      pid: '0',
      srId: _selectedSrId ?? 0,
      srAmount: double.tryParse(Utils.sanitizeNumber(_srAmountController.text)) ?? 0,
      rrId: _selectedRrId ?? 0,
      rrAmount: double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0,
      balance: double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0,
      status: TransactionStatus.active.index,
      timestamp: Utils.dateToTimestamp(_selectedDate),
      closable: true,
      meta: {'purchase_notes': _purchaseNotesController.text},
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
    return TextFormField(
      controller: _srAmountController,
      decoration: _input('Amount', 'e.g., 1.5'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
    );
  }

  Widget _buildSourceCryptoField() {
    return CryptoSearchField(
      labelText: 'Coin',
      initialValue: null,
      validator: _validateCrypto,
      onSelected: (id) => setState(() => _selectedSrId = id),
    );
  }

  Widget _buildResultAmountField() {
    return TextFormField(
      controller: _rrAmountController,
      decoration: _input('Amount', 'e.g., 10.5'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: _validateAmount,
    );
  }

  Widget _buildResultCryptoField() {
    return CryptoSearchField(
      labelText: 'Coin',
      initialValue: null,
      validator: _validateCrypto,
      onSelected: (id) => setState(() => _selectedRrId = id),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(controller: _purchaseNotesController, decoration: _input('Purchase Notes', 'Add notes...'), maxLines: 4);
  }

  Widget _buildTimestampField() {
    final currentDate = DateTime.now();

    return _buildDatePickerField(
      labelText: 'Date',
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: currentDate,
      onSelected: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildDatePickerField({
    required String labelText,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
  }) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(labelText: labelText),
      controller: TextEditingController(
        text: _selectedDate != null
            ? "${_selectedDate!.day.toString().padLeft(2, '0')}/"
                  "${_selectedDate!.month.toString().padLeft(2, '0')}/"
                  "${_selectedDate!.year}"
            : "",
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.text,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          onSelected(picked);
        }
      },
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

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }

    String val = Utils.sanitizeNumber(value);

    final parsed = double.tryParse(val);
    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }

    // if (parsed > 1e12) {
    //   return 'Amount is unrealistically large';
    // }

    return null;
  }

  String? _validateCrypto(int? value) {
    if (value == null || value == 0) {
      return 'Crypto is required';
    }

    if (_cryptosController.getSymbol(value) == null) {
      return 'Invalid crypto';
    }

    return null;
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/log.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../cryptos/search_field.dart';
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
  late CryptosController _cryptosController;

  TransactionsController get _txController => locator<TransactionsController>();

  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;
  late TextEditingController _tradingNotesController;

  int? _selectedRrId;
  DateTime? _selectedDate;

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
    _cryptosController = locator<CryptosController>();

    String purchaseNotes = '';
    if (widget.parent != null && widget.parent!.isRoot) {
      purchaseNotes = widget.parent!.meta['purchase_notes'];
    }

    _srAmountController = TextEditingController();
    _rrAmountController = TextEditingController();

    _purchaseNotesController = TextEditingController(text: purchaseNotes);

    _tradingNotesController = TextEditingController();

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

    final parent = widget.initialData!;

    final child = TransactionsModel(
      tid: generateTid(),
      rid: _saveRidField(),
      pid: parent.tid,
      srId: parent.rrId,
      srAmount: double.tryParse(Utils.sanitizeNumber(_srAmountController.text)) ?? 0,
      rrId: _selectedRrId ?? 0,
      rrAmount: double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0,
      balance: double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0,
      status: TransactionStatus.active.index,
      timestamp: Utils.dateToTimestamp(_selectedDate),
      closable: false,
      meta: _saveNotesField(),
    );

    final newParentBalance = parent.balance - child.srAmount;

    logln('[USER TRADE] from ${parent.tid} parent: ${parent.rrId} to child: ${child.srId}');
    logln('[USER TRADE] Calculated new parent balance: $newParentBalance (old: ${parent.balance} - child: ${child.srAmount})');

    TransactionStatus newStatus;
    if (newParentBalance <= 0) {
      newStatus = TransactionStatus.inactive;
    } else {
      newStatus = TransactionStatus.partial;
    }

    final updatedParent = parent.copyWith(balance: newParentBalance, status: newStatus.index);

    try {
      await _txController.add(child);
      await _txController.update(updatedParent);
      widget.onSave?.call(null);
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

    meta['trading_notes'] = _tradingNotesController.text;
    return meta;
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
    return Text('Trade Crypto', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    final balance = widget.initialData?.balance ?? 0;

    return TextFormField(
      controller: _srAmountController,
      decoration: _input('Amount', 'Max: ${Utils.formatSmartDouble(balance)}').copyWith(
        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard_double_arrow_up),
          tooltip: 'Use max',
          onPressed: () {
            _srAmountController.text = Utils.formatSmartDouble(balance).replaceAll(",", "");
          },
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: (value) => _validateAmountWithMax(value, balance),
    );
  }

  Widget _buildSourceCryptoField() {
    final data = widget.initialData!;
    return _buildReadOnlyCryptoDisplay(data.rrId);
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
      initialValue: _selectedRrId,
      validator: _validateCrypto,
      onSelected: (id) => setState(() => _selectedRrId = id),
    );
  }

  Widget _buildNotesField() {
    final existingNotes = _purchaseNotesController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (existingNotes.isNotEmpty) Text(existingNotes),
        if (existingNotes.isNotEmpty) const SizedBox(height: 24),
        TextFormField(
          controller: _tradingNotesController,
          decoration: _input('New Trading Notes', 'Add trade-specific notes...'),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildTimestampField() {
    TransactionsModel tx = widget.initialData!;

    final DateTime localParent = DateTime.fromMicrosecondsSinceEpoch(tx.sanitizedTimestamp, isUtc: true).toLocal();
    final DateTime firstDate = DateTime(localParent.year, localParent.month, localParent.day);

    return _buildDatePickerField(
      labelText: 'Date',
      initialDate: DateTime.now(),
      firstDate: firstDate,
      lastDate: DateTime.now(),
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
        WidgetButton(label: "Trade", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }

  Widget _buildReadOnlyCryptoDisplay(int? id) {
    final String text;
    if (id == null) {
      text = 'Unknown Crypto';
    } else {
      final crypto = _cryptosController.getById(id);
      text = crypto == null ? '$id' : '${crypto.symbol} (#${crypto.id})';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.separator),
        color: AppTheme.inputBg,
      ),
      child: Text(text, textAlign: TextAlign.start),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  String? _validateAmountWithMax(String? value, double max) {
    final base = _validateAmount(value);
    if (base != null) return base;

    final parsed = double.tryParse(value!) ?? 0;
    if (parsed > max) {
      return 'Amount cannot exceed $max';
    }

    return null;
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

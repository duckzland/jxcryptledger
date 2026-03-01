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

class TransactionFormEdit extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormEdit({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormEdit> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionFormEdit> {
  late CryptosController _cryptosController;

  TransactionsController get _txController => locator<TransactionsController>();

  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;
  late TextEditingController _tradingNotesController;

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;

  bool? _hasLeaf;

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

    final data = widget.initialData!;

    _srAmountController = TextEditingController(text: Utils.formatSmartDouble(data.srAmount).replaceAll(',', ''));
    _rrAmountController = TextEditingController(text: Utils.formatSmartDouble(data.rrAmount).replaceAll(',', ''));

    if (isRoot) {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: '');
    } else {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: data.meta['trading_notes'] ?? '');
    }

    _selectedSrId = data.srId;
    _selectedRrId = data.rrId;
    _selectedDate = DateTime.fromMicrosecondsSinceEpoch(widget.initialData!.sanitizedTimestamp, isUtc: true).toLocal();

    detectLeaf(data);
  }

  @override
  void dispose() {
    _srAmountController.dispose();
    _rrAmountController.dispose();
    _purchaseNotesController.dispose();
    super.dispose();
  }

  void detectLeaf(TransactionsModel tx) async {
    final leaf = await _txController.hasLeaf(tx);
    setState(() {
      _hasLeaf = leaf;
    });
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final data = widget.initialData!;
    TransactionsModel? parent = widget.parent;

    final tx = data.copyWith(
      srId: _saveSourceCryptoField(),
      srAmount: _saveSourceAmountField(),
      rrId: _saveResultCryptoField(),
      rrAmount: _saveResultAmountField(),
      balance: _saveBalanceField(),
      timestamp: _selectedDate != null ? Utils.dateToTimestamp(_selectedDate) : data.timestamp,
      meta: _saveNotesField(),
    );

    try {
      await _txController.update(tx);

      if (tx.isLeaf && parent != null && data.srAmount != tx.srAmount && parent.rrId == data.srId) {
        double newBalance = parent.balance;
        if (data.srAmount > tx.srAmount) {
          newBalance += data.srAmount - tx.srAmount;
        } else {
          double needToTake = tx.srAmount - data.srAmount;
          if (newBalance >= needToTake) {
            newBalance -= needToTake;
          }
        }

        final ptx = parent.copyWith(
          balance: newBalance,
          status: newBalance > 0 ? TransactionStatus.partial.index : TransactionStatus.inactive.index,
        );
        await _txController.update(ptx);
      }

      widget.onSave?.call(null);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  double _saveBalanceField() {
    final proposed = double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0;

    final data = widget.initialData!;

    if (isRoot) return proposed;
    if (isLeaf && isActive) return proposed;

    return data.balance;
  }

  int _saveSourceCryptoField() {
    final data = widget.initialData!;
    if (isRoot) return _selectedSrId ?? data.srId;
    return data.srId;
  }

  double _saveSourceAmountField() {
    final proposed = double.tryParse(Utils.sanitizeNumber(_srAmountController.text)) ?? 0;
    final data = widget.initialData!;
    if (isRoot) return proposed;
    if (isLeaf && isActive) return proposed;
    return data.srAmount;
  }

  int _saveResultCryptoField() {
    final data = widget.initialData!;
    if (isRoot) return _selectedRrId ?? data.rrId;
    if (isLeaf && isActive) return _selectedRrId ?? data.rrId;
    return data.rrId;
  }

  double _saveResultAmountField() {
    final proposed = double.tryParse(Utils.sanitizeNumber(_rrAmountController.text)) ?? 0;
    final data = widget.initialData!;
    if (isRoot) return proposed;
    if (isLeaf && isActive) return proposed;
    return data.rrAmount;
  }

  Map<String, dynamic> _saveNotesField() {
    final data = widget.initialData!;
    final meta = Map<String, dynamic>.from(data.meta);

    if (isRoot) {
      meta['purchase_notes'] = _purchaseNotesController.text;
    } else {
      meta['trading_notes'] = _tradingNotesController.text;
    }

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
    return Text('Edit Transaction', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    if (!isActive) {
      return _buildReadOnlyAmount(_srAmountController.text);
    } else {
      return TextFormField(
        controller: _srAmountController,
        decoration: _input('Amount', 'e.g., 1.5'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        validator: _validateAmount,
      );
    }
  }

  Widget _buildSourceCryptoField() {
    if (isRoot) {
      return CryptoSearchField(
        labelText: 'Coin',
        initialValue: _selectedSrId,
        validator: _validateCrypto,
        onSelected: (id) => setState(() => _selectedSrId = id),
      );
    } else {
      return _buildReadOnlyCryptoDisplay(_selectedSrId);
    }
  }

  Widget _buildResultAmountField() {
    if (isRoot) {
      return TextFormField(
        controller: _rrAmountController,
        decoration: _input('Amount', 'e.g., 10.5'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        validator: _validateAmount,
      );
    } else {
      if (!isActive) {
        return _buildReadOnlyAmount(_rrAmountController.text);
      } else {
        return TextFormField(
          controller: _rrAmountController,
          decoration: _input('Amount', 'e.g., 10.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );
      }
    }
  }

  Widget _buildResultCryptoField() {
    if (isRoot) {
      return CryptoSearchField(
        labelText: 'Coin',
        initialValue: _selectedRrId,
        validator: _validateCrypto,
        onSelected: (id) => setState(() => _selectedRrId = id),
      );
    } else {
      if (!isActive) {
        return _buildReadOnlyCryptoDisplay(_selectedRrId);
      } else {
        return CryptoSearchField(
          labelText: 'Coin',
          initialValue: _selectedRrId,
          validator: _validateCrypto,
          onSelected: (id) => setState(() => _selectedRrId = id),
        );
      }
    }
  }

  Widget _buildNotesField() {
    if (isRoot) {
      return TextFormField(controller: _purchaseNotesController, decoration: _input('Purchase Notes', 'Edit notes...'), maxLines: 4);
    } else {
      return TextFormField(controller: _tradingNotesController, decoration: _input('Trading Notes', 'Edit trading notes...'), maxLines: 4);
    }
  }

  Widget _buildTimestampField() {
    TransactionsModel tx = widget.initialData!;
    final initialDate = DateTime.fromMicrosecondsSinceEpoch(tx.sanitizedTimestamp, isUtc: true).toLocal();
    final hasLeaf = _hasLeaf ?? false;

    if (!hasLeaf) {
      DateTime firstDate = DateTime(2000).toLocal();
      if (widget.parent != null) {
        final DateTime localParent = DateTime.fromMicrosecondsSinceEpoch(widget.parent!.sanitizedTimestamp, isUtc: true).toLocal();
        firstDate = DateTime(localParent.year, localParent.month, localParent.day);
      }

      return _buildDatePickerField(
        labelText: 'Date',
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: DateTime.now().toLocal(),
        onSelected: (date) => setState(() => _selectedDate = date),
      );
    } else {
      return _buildReadOnlyDateDisplay(initialDate);
    }
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

  Widget _buildReadOnlyDateDisplay(DateTime date) {
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText: 'Date'),
      controller: TextEditingController(text: "${date.year}-${date.month}-${date.day}"),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetButton(label: "Update", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
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

  Widget _buildReadOnlyAmount(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.separator),
        color: AppTheme.inputBg,
      ),
      child: Text(value.isEmpty ? '0' : value),
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

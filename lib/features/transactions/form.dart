import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/transactions/repository.dart';

import '../../app/theme.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../../core/utils.dart';
import '../../widgets/button.dart';
import '../../widgets/panel.dart';
import '../cryptos/repository.dart';
import '../cryptos/search_field.dart';
import 'controller.dart';
import 'model.dart';

enum TransactionsFormActionMode { addNew, edit, trade }

class TransactionForm extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final TransactionsFormActionMode mode;

  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionForm({super.key, required this.onSave, required this.mode, this.initialData, this.parent});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late CryptosRepository _cryptosRepo;

  TransactionsController get _txController => locator<TransactionsController>();
  TransactionsRepository get _txRepo => locator<TransactionsRepository>();

  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;
  late TextEditingController _tradingNotesController;

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;

  final _formKey = GlobalKey<FormState>();

  bool get isRoot {
    final tx = widget.initialData;
    return tx != null && tx.isRoot;
  }

  bool get isLeaf => !isRoot;
  bool get isActive => widget.initialData?.statusEnum == TransactionStatus.active;

  String generateTid() => _txRepo.generateTid();

  @override
  void initState() {
    super.initState();

    _cryptosRepo = locator<CryptosRepository>();

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        _initAddNew();
        break;

      case TransactionsFormActionMode.trade:
        _initTrade();
        break;

      case TransactionsFormActionMode.edit:
        _initEdit();
        break;
    }
  }

  void _initAddNew() {
    _srAmountController = TextEditingController();
    _rrAmountController = TextEditingController();
    _purchaseNotesController = TextEditingController();

    _selectedSrId = null;
    _selectedRrId = null;
    _selectedDate = DateTime.now();
  }

  void _initTrade() {
    final parent = widget.parent!;

    _srAmountController = TextEditingController();
    _rrAmountController = TextEditingController();

    _purchaseNotesController = TextEditingController(text: parent.meta['purchase_notes'] ?? '');

    _tradingNotesController = TextEditingController();

    _selectedSrId = parent.srId;
    _selectedRrId = null;

    _selectedDate =  DateTime.fromMillisecondsSinceEpoch(
      widget.parent!.timestampAsMs,
    );

  }

  void _initEdit() {
    final data = widget.initialData!;

    _srAmountController = TextEditingController(text: Utils.formatSmartDouble(data.srAmount));
    _rrAmountController = TextEditingController(text: Utils.formatSmartDouble(data.rrAmount));

    if (isRoot) {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: '');
    } else {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: data.meta['trading_notes'] ?? '');
    }

    _selectedSrId = data.srId;
    _selectedRrId = data.rrId;
    _selectedDate = DateTime.fromMillisecondsSinceEpoch(
      widget.initialData!.timestampAsMs,
    );
  }

  @override
  void dispose() {
    _srAmountController.dispose();
    _rrAmountController.dispose();
    _purchaseNotesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        _saveAddNew();
        break;

      case TransactionsFormActionMode.trade:
        _saveTrade();
        break;

      case TransactionsFormActionMode.edit:
        _saveEdit();
        break;
    }
  }

  void _saveAddNew() async {
    final tx = TransactionsModel(
      tid: generateTid(),
      rid: _saveRidField(),
      pid: _savePidField(),
      srId: _saveSourceCryptoField(),
      srAmount: _saveSourceAmountField(),
      rrId: _saveResultCryptoField(),
      rrAmount: _saveResultAmountField(),
      balance: _saveBalanceField(),
      status: _saveStatusField(),
      timestamp: _saveTimestampField(),
      closable: _saveClosableField(),
      meta: _saveNotesField(),
    );

    try {
      await _txController.add(tx);
      widget.onSave?.call(null);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  void _saveTrade() async {
    final parent = widget.initialData!;

    final child = TransactionsModel(
      tid: generateTid(),
      rid: _saveRidField(),
      pid: _savePidField(),
      srId: _saveSourceCryptoField(),
      srAmount: _saveSourceAmountField(),
      rrId: _saveResultCryptoField(),
      rrAmount: _saveResultAmountField(),
      balance: _saveBalanceField(),
      status: _saveStatusField(),
      timestamp: _saveTimestampField(),
      closable: _saveClosableField(),
      meta: _saveNotesField(),
    );

    final newParentBalance = parent.balance - child.srAmount;

    logln('Calculated new parent balance: $newParentBalance (old: ${parent.balance} - child: ${child.srAmount})');

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

  void _saveEdit() async {
    final data = widget.initialData!;

    final tx = data.copyWith(
      srId: _saveSourceCryptoField(),
      srAmount: _saveSourceAmountField(),
      rrId: _saveResultCryptoField(),
      rrAmount: _saveResultAmountField(),
      balance: _saveBalanceField(),
      status: _saveStatusField(),
      closable: _saveClosableField(),
      meta: _saveNotesField(),
    );

    try {
      await _txController.update(tx);
      widget.onSave?.call(null);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  String _saveRidField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return '0';

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        if (data.isRoot) {
          return '0';
        }
        return data.rid;

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        if (data.isRoot) {
          return data.tid;
        }
        return data.rid;
    }
  }

int _saveTimestampField() {
  final data = widget.initialData;

  switch (widget.mode) {
    case TransactionsFormActionMode.addNew:
    case TransactionsFormActionMode.trade:
      final date = _selectedDate ?? DateTime.now();
      return date.toUtc().millisecondsSinceEpoch;

    case TransactionsFormActionMode.edit:
      if (_selectedDate != null) {
        return _selectedDate!.toUtc().millisecondsSinceEpoch;
      }

      return data!.timestampAsMs;
  }
}

  String _savePidField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return '0';

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        return data.pid;

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        return data.tid;
    }
  }

  double _saveBalanceField() {
    final proposed = double.tryParse(_rrAmountController.text) ?? 0;

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return proposed;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;

        if (isRoot) return proposed;
        if (isLeaf && isActive) return proposed;

        return data.balance;

      case TransactionsFormActionMode.trade:
        return proposed;
    }
  }

  int _saveStatusField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return TransactionStatus.active.index;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        return data.status;

      case TransactionsFormActionMode.trade:
        return TransactionStatus.active.index;
    }
  }

  bool _saveClosableField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return true;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        return data.closable;

      case TransactionsFormActionMode.trade:
        // We must drill up to check!
        return false;
    }
  }

  int _saveSourceCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return _selectedSrId ?? 0;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        if (isRoot) return _selectedSrId ?? data.srId;
        return data.srId;

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        return data.rrId;
    }
  }

  double _saveSourceAmountField() {
    final proposed = double.tryParse(_srAmountController.text) ?? 0;

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return proposed;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        if (isRoot) return proposed;
        if (isLeaf && isActive) return proposed;
        return data.srAmount;

      case TransactionsFormActionMode.trade:
        return proposed;
    }
  }

  int _saveResultCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return _selectedRrId ?? 0;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        if (isRoot) return _selectedRrId ?? data.rrId;
        if (isLeaf && isActive) return _selectedRrId ?? data.rrId;
        return data.rrId;

      case TransactionsFormActionMode.trade:
        return _selectedRrId ?? 0;
    }
  }

  double _saveResultAmountField() {
    final proposed = double.tryParse(_rrAmountController.text) ?? 0;

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return proposed;

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        if (isRoot) return proposed;
        if (isLeaf && isActive) return proposed;
        return data.rrAmount;

      case TransactionsFormActionMode.trade:
        return proposed;
    }
  }

  Map<String, dynamic> _saveNotesField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return {'purchase_notes': _purchaseNotesController.text};

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        final meta = Map<String, dynamic>.from(data.meta);

        if (isRoot) {
          meta['purchase_notes'] = _purchaseNotesController.text;
        } else {
          meta['trading_notes'] = _tradingNotesController.text;
        }

        return meta;

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        final meta = Map<String, dynamic>.from(data.meta);

        meta['trading_notes'] = _tradingNotesController.text;
        return meta;
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
    final title = switch (widget.mode) {
      TransactionsFormActionMode.edit => 'Edit Transaction',
      TransactionsFormActionMode.trade => 'Trade Crypto',
      _ => 'New Transaction',
    };

    return Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return TextFormField(
          controller: _srAmountController,
          decoration: _input('Amount', 'e.g., 1.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return TextFormField(
            controller: _srAmountController,
            decoration: _input('Amount', 'e.g., 1.5'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            validator: _validateAmount,
          );
        } else {
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

      case TransactionsFormActionMode.trade:
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
  }

  Widget _buildSourceCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return CryptoSearchField(
          labelText: 'Coin',
          initialValue: null,
          validator: _validateCrypto,
          onSelected: (id) => setState(() => _selectedSrId = id),
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return CryptoSearchField(
            labelText: 'Coin',
            initialValue: _selectedSrId,
            validator: (value) {
              if (value == null || value == 0) return 'Crypto is required';
              if (_cryptosRepo.getSymbol(value) == null) return 'Invalid crypto';
              return null;
            },
            onSelected: (id) => setState(() => _selectedSrId = id),
          );
        } else {
          return _buildReadOnlyCryptoDisplay(_selectedSrId);
        }

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        return _buildReadOnlyCryptoDisplay(data.rrId);
    }
  }

  Widget _buildResultAmountField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return TextFormField(
          controller: _rrAmountController,
          decoration: _input('Amount', 'e.g., 10.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );

      case TransactionsFormActionMode.edit:
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

      case TransactionsFormActionMode.trade:
        return TextFormField(
          controller: _rrAmountController,
          decoration: _input('Amount', 'e.g., 10.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );
    }
  }

  Widget _buildResultCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return CryptoSearchField(
          labelText: 'Coin',
          initialValue: null,
          validator: _validateCrypto,
          onSelected: (id) => setState(() => _selectedRrId = id),
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return CryptoSearchField(
            labelText: 'Coin',
            initialValue: _selectedRrId,
            validator: (value) {
              if (value == null || value == 0) return 'Crypto is required';
              if (_cryptosRepo.getSymbol(value) == null) return 'Invalid crypto';
              return null;
            },
            onSelected: (id) => setState(() => _selectedRrId = id),
          );
        } else {
          if (!isActive) {
            return _buildReadOnlyCryptoDisplay(_selectedRrId);
          } else {
            return CryptoSearchField(
              labelText: 'Coin',
              initialValue: _selectedRrId,
              validator: (value) {
                if (value == null || value == 0) return 'Crypto is required';
                if (_cryptosRepo.getSymbol(value) == null) return 'Invalid crypto';
                return null;
              },
              onSelected: (id) => setState(() => _selectedRrId = id),
            );
          }
        }

      case TransactionsFormActionMode.trade:
        return CryptoSearchField(
          labelText: 'Coin',
          initialValue: _selectedRrId,
          validator: (value) {
            if (value == null || value == 0) return 'Crypto is required';
            if (_cryptosRepo.getSymbol(value) == null) return 'Invalid crypto';
            return null;
          },
          onSelected: (id) => setState(() => _selectedRrId = id),
        );
    }
  }

  Widget _buildNotesField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return TextFormField(
          controller: _purchaseNotesController,
          decoration: _input('Purchase Notes', 'Add notes...'),
          maxLines: 4,
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return TextFormField(
            controller: _purchaseNotesController,
            decoration: _input('Purchase Notes', 'Edit notes...'),
            maxLines: 4,
          );
        } else {
          return TextFormField(
            controller: _tradingNotesController,
            decoration: _input('Trading Notes', 'Edit trading notes...'),
            maxLines: 4,
          );
        }

      case TransactionsFormActionMode.trade:
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
  }

  Widget _buildTimestampField() {
  final tx = widget.initialData!;


  switch (widget.mode) {
    case TransactionsFormActionMode.addNew:
      final currentDate =  DateTime.now();

      return _buildDatePickerField(
        labelText: 'Date',
        initialDate: currentDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onSelected: (date) => setState(() => _selectedDate = date),
      );

    case TransactionsFormActionMode.edit:
      final currentDate = DateTime.fromMillisecondsSinceEpoch(tx.timestampAsMs);

      return FutureBuilder<bool>(
        future: _txController.hasLeaf(tx),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          final hasLeaf = snapshot.data!;
          if (!hasLeaf && tx.isActive) {
            return _buildDatePickerField(
              labelText: 'Date',
              initialDate: currentDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onSelected: (date) => setState(() => _selectedDate = date),
            );
          } else {
            return _buildReadOnlyDateDisplay(currentDate);
          }
        },
      );

    case TransactionsFormActionMode.trade:
      final currentDate = DateTime.fromMillisecondsSinceEpoch(tx.timestampAsMs);

      return _buildDatePickerField(
        labelText: 'Date',
        initialDate: DateTime.now(),
        firstDate: currentDate,
        lastDate: DateTime(2100),
        onSelected: (date) => setState(() => _selectedDate = date),
      );
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
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
    controller: TextEditingController(
      text: "${date.year}-${date.month}-${date.day}",
    ),
  );
}

  Widget _buildButtons() {
    String mode = "Save";

    switch (widget.mode) {
      case TransactionsFormActionMode.edit:
        mode = "Update";
        break;
      case TransactionsFormActionMode.addNew:
        mode = "Create New";
        break;
      case TransactionsFormActionMode.trade:
        mode = "Trade";
        break;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetButton(label: mode, initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }

  Widget _buildReadOnlyCryptoDisplay(int? id) {
    final String text;
    if (id == null) {
      text = 'Unknown Crypto';
    } else {
      final crypto = _cryptosRepo.getById(id);
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

    String val = value.replaceAll(",", "");

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

    if (_cryptosRepo.getSymbol(value) == null) {
      return 'Invalid crypto';
    }

    return null;
  }
}

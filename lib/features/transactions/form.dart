import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/locator.dart';
import '../../core/log.dart';
import '../../widgets/button.dart';
import '../cryptos/repository.dart';
import '../cryptos/search_field.dart';
import 'controller.dart';
import 'model.dart';

enum TransactionsFormActionMode { addNew, edit, trade }

class TransactionForm extends StatefulWidget {
  final void Function() onSave;
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

  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;
  late TextEditingController _tradingNotesController;

  int? _selectedSrId;
  int? _selectedRrId;

  final _formKey = GlobalKey<FormState>();

  bool get isRoot {
    final tx = widget.initialData;
    return tx != null && tx.rid == 0 && tx.pid == 0;
  }

  bool get isLeaf => !isRoot;
  bool get isActive => widget.initialData?.statusEnum == TransactionStatus.active;

  final _uuid = Uuid();

  String generateTid() => _uuid.v4();

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
  }

  void _initTrade() {
    final parent = widget.parent!;

    _srAmountController = TextEditingController();
    _rrAmountController = TextEditingController();

    _purchaseNotesController = TextEditingController(text: parent.meta['purchase_notes'] ?? '');

    _tradingNotesController = TextEditingController();

    _selectedSrId = parent.srId;
    _selectedRrId = null;
  }

  void _initEdit() {
    final data = widget.initialData!;

    _srAmountController = TextEditingController(text: data.srAmount.toString());
    _rrAmountController = TextEditingController(text: data.rrAmount.toString());

    if (isRoot) {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: '');
    } else {
      _purchaseNotesController = TextEditingController(text: data.meta['purchase_notes'] ?? '');
      _tradingNotesController = TextEditingController(text: data.meta['trading_notes'] ?? '');
    }

    _selectedSrId = data.srId;
    _selectedRrId = data.rrId;
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
      meta: _saveNotesField(),
    );

    await _txController.add(tx);

    widget.onSave();
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

    await _txController.add(child);
    await _txController.update(updatedParent);

    widget.onSave();
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
      meta: _saveNotesField(),
    );

    await _txController.update(tx);

    widget.onSave();
  }

  String _saveRidField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return '0';

      case TransactionsFormActionMode.edit:
        final data = widget.initialData!;
        return data.rid;

      case TransactionsFormActionMode.trade:
        final data = widget.initialData!;
        return data.pid;
    }
  }

  int _saveTimestampField() {
    final data = widget.initialData;

    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
      case TransactionsFormActionMode.trade:
        return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      case TransactionsFormActionMode.edit:
        return data!.timestamp;
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

                _buildSourceAmountField(),
                const SizedBox(height: 16),

                _buildSourceCryptoField(),
                const SizedBox(height: 16),

                _buildResultAmountField(),
                const SizedBox(height: 16),

                _buildResultCryptoField(),
                const SizedBox(height: 16),

                _buildNotesField(),

                const SizedBox(height: 24),

                _buildButtons(),
              ],
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
          decoration: _input('Source Amount', 'e.g., 1.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return TextFormField(
            controller: _srAmountController,
            decoration: _input('Source Amount', 'e.g., 1.5'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            validator: _validateAmount,
          );
        } else {
          if (!isActive) {
            return _buildReadOnlyAmount(_srAmountController.text);
          } else {
            return TextFormField(
              controller: _srAmountController,
              decoration: _input('Source Amount', 'e.g., 1.5'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: _validateAmount,
            );
          }
        }

      case TransactionsFormActionMode.trade:
        final balance = widget.initialData?.balance ?? 0;

        return TextFormField(
          controller: _srAmountController,
          decoration: _input('Source Amount', 'Max: $balance'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: (value) => _validateAmountWithMax(value, balance),
        );
    }
  }

  Widget _buildSourceCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return CryptoSearchField(
          labelText: 'Source Crypto',
          initialValue: null,
          validator: _validateCrypto,
          onSelected: (id) => setState(() => _selectedSrId = id),
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return CryptoSearchField(
            labelText: 'Source Crypto',
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
          decoration: _input('Result Amount', 'e.g., 10.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return TextFormField(
            controller: _rrAmountController,
            decoration: _input('Result Amount', 'e.g., 10.5'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            validator: _validateAmount,
          );
        } else {
          if (!isActive) {
            return _buildReadOnlyAmount(_rrAmountController.text);
          } else {
            return TextFormField(
              controller: _rrAmountController,
              decoration: _input('Result Amount', 'e.g., 10.5'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: _validateAmount,
            );
          }
        }

      case TransactionsFormActionMode.trade:
        return TextFormField(
          controller: _rrAmountController,
          decoration: _input('Result Amount', 'e.g., 10.5'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          validator: _validateAmount,
        );
    }
  }

  Widget _buildResultCryptoField() {
    switch (widget.mode) {
      case TransactionsFormActionMode.addNew:
        return CryptoSearchField(
          labelText: 'Result Crypto',
          initialValue: null,
          validator: _validateCrypto,
          onSelected: (id) => setState(() => _selectedRrId = id),
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          return CryptoSearchField(
            labelText: 'Result Crypto',
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
              labelText: 'Result Crypto',
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
          labelText: 'Result Crypto',
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
        // Root add → purchase_notes only
        return TextFormField(
          controller: _purchaseNotesController,
          decoration: _input('Purchase Notes', 'Add notes...'),
          maxLines: 4,
        );

      case TransactionsFormActionMode.edit:
        if (isRoot) {
          // Edit root → purchase_notes editable
          return TextFormField(
            controller: _purchaseNotesController,
            decoration: _input('Purchase Notes', 'Edit notes...'),
            maxLines: 4,
          );
        } else {
          // Edit leaf → trading_notes editable, purchase_notes not editable here
          return TextFormField(
            controller: _tradingNotesController,
            decoration: _input('Trading Notes', 'Edit trading notes...'),
            maxLines: 4,
          );
        }

      case TransactionsFormActionMode.trade:
        // Trade (leaf) → purchase_notes read-only + trading_notes editable
        final existingNotes = _purchaseNotesController.text;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Original Purchase Notes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Text(existingNotes.isEmpty ? 'No notes' : existingNotes),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tradingNotesController,
              decoration: _input('Trading Notes', 'Add trade-specific notes...'),
              maxLines: 4,
            ),
          ],
        );
    }
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetButton(label: mode, initialState: WidgetButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }

  Widget _buildReadOnlyCryptoDisplay(int? id) {
    if (id == null) {
      return const Text('Unknown Crypto');
    }

    final crypto = _cryptosRepo.getById(id);
    final text = crypto == null ? '$id' : '${crypto.id} - ${crypto.symbol}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(text),
    );
  }

  Widget _buildReadOnlyAmount(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(value.isEmpty ? '0' : value),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }

    if (parsed > 1e12) {
      return 'Amount is unrealistically large';
    }

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

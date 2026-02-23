import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../widgets/button.dart';
import '../cryptos/search_field.dart';
import 'model.dart';

class TransactionForm extends StatefulWidget {
  final Function(TransactionsModel) onSave;
  final TransactionsModel? initialData;
  final bool isRootTransaction;
  final TransactionsModel? parent;
  final bool isTrade;

  const TransactionForm({
    super.key,
    required this.onSave,
    this.initialData,
    this.isRootTransaction = true,
    this.parent,
    this.isTrade = false,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late TextEditingController _srAmountController;
  late TextEditingController _rrAmountController;
  late TextEditingController _purchaseNotesController;

  int? _selectedSrId;
  int? _selectedRrId;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    final parent = widget.parent;

    if (widget.isTrade && parent != null) {
      // Trade mode: prefill srId from parent, amounts left empty
      _srAmountController = TextEditingController(text: '');
      _rrAmountController = TextEditingController(text: '');
      _purchaseNotesController = TextEditingController(text: '');

      _selectedSrId = parent.srId;
      _selectedRrId = null;
    } else {
      _srAmountController = TextEditingController(text: data?.srAmount.toString() ?? '');
      _rrAmountController = TextEditingController(text: data?.rrAmount.toString() ?? '');
      _purchaseNotesController = TextEditingController(text: data?.meta['purchase_notes']?.toString() ?? '');

      _selectedSrId = data?.srId;
      _selectedRrId = data?.rrId;
    }
  }

  @override
  void dispose() {
    _srAmountController.dispose();
    _rrAmountController.dispose();
    _purchaseNotesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSrId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select source crypto')));
      return;
    }

    if (_selectedRrId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select result crypto')));
      return;
    }

    final srAmount = double.parse(_srAmountController.text);
    final rrAmount = double.parse(_rrAmountController.text);

    // If trade mode, enforce srAmount <= parent.balance
    if (widget.isTrade && widget.parent != null) {
      final parent = widget.parent!;
      if (srAmount > parent.balance) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Source amount cannot exceed parent balance')));
        return;
      }
    }

    final newTid = widget.initialData?.tid ?? const Uuid().v4();

    final rid =
        widget.initialData?.rid ??
        (widget.parent != null ? (widget.parent!.rid == '0' ? widget.parent!.tid : widget.parent!.rid) : '0');

    final pid = widget.initialData?.pid ?? (widget.parent?.tid ?? '0');

    final meta = <String, dynamic>{};
    // For trade mode we need trade_notes keyed by this tid
    if (widget.isTrade) {
      meta['trade_notes'] = {newTid: _purchaseNotesController.text};
    } else {
      meta['purchase_notes'] = _purchaseNotesController.text;
    }

    final transaction = TransactionsModel(
      tid: newTid,
      rid: rid,
      pid: pid,
      srAmount: srAmount,
      srId: _selectedSrId!,
      rrAmount: rrAmount,
      rrId: _selectedRrId!,
      balance: rrAmount,
      status: 1,
      timestamp: widget.initialData?.timestamp ?? DateTime.now().millisecondsSinceEpoch,
      meta: meta,
    );

    widget.onSave(transaction);
    Navigator.pop(context);
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.initialData != null ? 'Edit Transaction' : 'New Transaction',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 24),
                // Source Amount
                TextFormField(
                  controller: _srAmountController,
                  decoration: InputDecoration(
                    labelText: 'Source Amount',
                    hintText: 'e.g., 1.5 or -0.25',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Source amount is required';
                    }
                    try {
                      double.parse(value);
                      return null;
                    } catch (_) {
                      return 'Please enter a valid number';
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Source Crypto
                CryptoSearchField(
                  labelText: 'Source Crypto',
                  onSelected: (cryptoId) {
                    setState(() {
                      _selectedSrId = cryptoId;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Result Amount
                TextFormField(
                  controller: _rrAmountController,
                  decoration: InputDecoration(
                    labelText: 'Result Amount',
                    hintText: 'e.g., 10.5 or -2.0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Result amount is required';
                    }
                    try {
                      double.parse(value);
                      return null;
                    } catch (_) {
                      return 'Please enter a valid number';
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Result Crypto
                CryptoSearchField(
                  labelText: 'Result Crypto',
                  onSelected: (cryptoId) {
                    setState(() {
                      _selectedRrId = cryptoId;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Purchase Notes
                TextFormField(
                  controller: _purchaseNotesController,
                  decoration: InputDecoration(
                    labelText: 'Purchase Notes',
                    hintText: 'Add any notes about this transaction...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    WidgetButton(
                      label: 'Cancel',
                      onPressed: (_) {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 12),
                    WidgetButton(
                      label: widget.initialData != null ? 'Update' : 'Save',
                      onPressed: (_) {
                        _handleSave();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/datepicker.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../cryptos/controller.dart';
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
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;

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

    final data = widget.initialData!;

    _selectedSrId = data.srId;
    _selectedRrId = data.rrId;
    _selectedDate = DateTime.fromMicrosecondsSinceEpoch(widget.initialData!.sanitizedTimestamp, isUtc: true).toLocal();
    _srAmount = Utils.formatSmartDouble(data.srAmount).replaceAll(',', '');
    _rrAmount = Utils.formatSmartDouble(data.rrAmount).replaceAll(',', '');
    _noteEntry = isRoot ? data.meta['purchase_notes'] ?? '' : data.meta['trading_notes'] ?? '';

    detectLeaf(data);
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
      widget.onSave?.call(null);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  double _saveBalanceField() {
    final proposed = _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0;

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
    final proposed = _srAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_srAmount!)) ?? 0;
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
    final proposed = _rrAmount == null ? 0.0 : double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0;
    final data = widget.initialData!;
    if (isRoot) return proposed;
    if (isLeaf && isActive) return proposed;
    return data.rrAmount;
  }

  Map<String, dynamic> _saveNotesField() {
    final data = widget.initialData!;
    final meta = Map<String, dynamic>.from(data.meta);

    if (isRoot) {
      meta['purchase_notes'] = _noteEntry;
    } else {
      meta['trading_notes'] = _noteEntry;
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
                                    if (isRoot) const SizedBox(width: 12),
                                    if (isRoot) Flexible(flex: 2, child: _buildSourceCryptoField()),
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
                                    if (!(!isRoot && !isActive)) const SizedBox(width: 12),
                                    if (!(!isRoot && !isActive)) Flexible(flex: 2, child: _buildResultCryptoField()),
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
    String? symbol;

    if (!isRoot) {
      final data = widget.initialData;
      final srid = data?.srId ?? 0;
      symbol = _cryptoController.getSymbol(srid);
    }

    return WidgetsFieldsAmount(
      title: 'Amount',
      initialValue: _srAmount,
      suffixText: symbol,
      enabled: isActive,
      helperText: 'e.g., 1.5',
      onChanged: (value) {
        _srAmount = value;
      },
    );
  }

  Widget _buildSourceCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: _selectedSrId,
      enabled: isRoot,
      onSelected: (id) => setState(() => _selectedSrId = id),
    );
  }

  Widget _buildResultAmountField() {
    String? symbol;

    if (!isRoot && !isActive) {
      final data = widget.initialData;
      final rrid = data?.rrId ?? 0;
      symbol = _cryptoController.getSymbol(rrid);
    }

    return WidgetsFieldsAmount(
      title: 'Amount',
      initialValue: _rrAmount,
      suffixText: symbol,
      enabled: isRoot || isActive,
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
      enabled: !(!isRoot && !isActive),
      onSelected: (id) => setState(() => _selectedRrId = id),
    );
  }

  Widget _buildNotesField() {
    return WidgetsFieldsTextarea(
      title: isRoot ? 'Purchase Notes' : 'Trading Notes',
      helperText: isRoot ? 'Edit purchase notes..' : 'Edit trading notes...',
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildTimestampField() {
    TransactionsModel tx = widget.initialData!;
    final initialDate = DateTime.fromMicrosecondsSinceEpoch(tx.sanitizedTimestamp, isUtc: true).toLocal();
    final hasLeaf = _hasLeaf ?? false;
    DateTime firstDate = DateTime(2000).toLocal();
    if (widget.parent != null) {
      final DateTime localParent = DateTime.fromMicrosecondsSinceEpoch(widget.parent!.sanitizedTimestamp, isUtc: true).toLocal();
      firstDate = DateTime(localParent.year, localParent.month, localParent.day);
    }

    return WidgetsFieldsDatepicker(
      labelText: 'Date',
      enabled: !hasLeaf,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().toLocal(),
      onSelected: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetsButton(label: "Update", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

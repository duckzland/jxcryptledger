import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/datepicker.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionFormEdit extends StatefulWidget {
  final void Function(Object? error, TransactionsModel? tx)? onSave;
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionFormEdit({super.key, required this.onSave, this.initialData, this.parent});

  @override
  State<TransactionFormEdit> createState() => _TransactionFormEditState();
}

class _TransactionFormEditState extends State<TransactionFormEdit> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  int? _selectedSrId;
  int? _selectedRrId;
  DateTime? _selectedDate;
  String? _srAmount;
  String? _rrAmount;
  String? _noteEntry;

  bool? _hasLeaf;
  bool _isActive = true;

  final _formKey = GlobalKey<FormState>();

  bool get isRoot {
    final tx = widget.initialData;
    return tx != null && tx.isRoot;
  }

  bool get isLeaf => !isRoot;

  bool _isCapital = false;

  String generateTid() => _txController.generateId();

  @override
  void initState() {
    super.initState();

    final data = widget.initialData!;

    _isCapital = data.isCapital;
    detectLeaf(data);

    _isActive = widget.initialData?.statusEnum == TransactionStatus.active;
  }

  void detectLeaf(TransactionsModel tx) {
    final leaf = _txController.hasLeaf(tx);
    setState(() {
      _hasLeaf = leaf;
      if (_hasLeaf!) {
        _isActive = false;
      }
    });
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final data = widget.initialData!;

    try {
      final srId = _saveSourceCryptoField();
      final srAmount = _saveSourceAmountField();
      final timestamp = _selectedDate != null ? Utils.dateToTimestamp(_selectedDate) : data.timestamp;
      final meta = _saveNotesField();
      double balance = _saveBalanceField();

      int rrId = _saveResultCryptoField();
      double rrAmount = _saveResultAmountField();

      if (_isCapital) {
        rrAmount = srAmount;
        balance = srAmount;
        rrId = srId;
      } else {
        if (rrAmount == srAmount && rrId == srId) {
          throw ValidationException(
            AppErrorCode.txBasicSrIdEqualsRrId,
            "srId must not equal rrId (srId=$srId, rrId=$rrId).",
            "Source and target coin must be different.",
          );
        }
      }

      final tx = data.copyWith(
        srId: srId,
        srAmount: srAmount,
        rrId: rrId,
        rrAmount: rrAmount,
        balance: balance,
        timestamp: timestamp,
        meta: meta,
      );

      await _txController.update(tx);
      widget.onSave?.call(null, tx);
    } on ValidationException catch (e) {
      widget.onSave?.call(e, null);
    } catch (e) {
      widget.onSave?.call(e, null);
    }
  }

  double _saveBalanceField() {
    final data = widget.initialData!;

    if (_rrAmount != null) {
      final proposed = double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0;
      if (isRoot) return proposed;
      if (isLeaf && _isActive) return proposed;
    }

    return data.balance;
  }

  int _saveSourceCryptoField() {
    final data = widget.initialData!;
    if (_selectedSrId != null) {
      if (isRoot) return _selectedSrId!;
    }
    return data.srId;
  }

  double _saveSourceAmountField() {
    final data = widget.initialData!;
    if (_srAmount != null) {
      final proposed = double.tryParse(Utils.sanitizeNumber(_srAmount!)) ?? 0;
      if (isRoot) return proposed;
      if (isLeaf && _isActive) return proposed;
    }
    return data.srAmount;
  }

  int _saveResultCryptoField() {
    final data = widget.initialData!;
    if (_selectedRrId != null) {
      if (isRoot) return _selectedRrId!;
      if (isLeaf && _isActive) return _selectedRrId!;
    }
    return data.rrId;
  }

  double _saveResultAmountField() {
    final data = widget.initialData!;

    if (_rrAmount != null) {
      final proposed = double.tryParse(Utils.sanitizeNumber(_rrAmount!)) ?? 0;
      if (isRoot) return proposed;
      if (isLeaf && _isActive) return proposed;
    }

    return data.rrAmount;
  }

  Map<String, dynamic> _saveNotesField() {
    final data = widget.initialData!;
    if (_noteEntry != null) {
      final meta = Map<String, dynamic>.from(data.meta);
      if (isRoot) {
        meta['purchase_notes'] = _noteEntry;
      } else {
        meta['trading_notes'] = _noteEntry;
      }

      return meta;
    }

    return data.meta;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1600),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 30,
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

                          if (!isRoot || !_isCapital) Column(children: const [SizedBox(height: 42), Icon(Icons.arrow_forward, size: 24)]),

                          if (!isRoot || !_isCapital) Expanded(child: _buildToPanel()),
                        ],
                      );
                    } else {
                      return Column(spacing: 30, children: [_buildDatePanel(), _buildFromPanel(), _buildToPanel()]);
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
    );
  }

  Widget _buildDatePanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("On date:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        _buildTimestampField(),
      ],
    );
  }

  Widget _buildFromPanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isRoot
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("From:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  const Spacer(),
                  SizedBox(
                    height: 20,
                    child: Checkbox(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: _isCapital,
                      onChanged: (v) => setState(() {
                        _isCapital = v!;
                        _selectedRrId = null;
                        _rrAmount = null;
                      }),
                    ),
                  ),
                  const Text("Set as capital"),
                ],
              )
            : const Text("From:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Row(
          spacing: 12,
          children: [
            Flexible(flex: 3, child: _buildSourceAmountField()),
            if (isRoot) Flexible(flex: 2, child: _buildSourceCryptoField()),
          ],
        ),
      ],
    );
  }

  Widget _buildToPanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("To:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Row(
          spacing: 12,
          children: [
            Flexible(flex: 3, child: _buildResultAmountField()),
            if (!(!isRoot && !_isActive)) Flexible(flex: 2, child: _buildResultCryptoField()),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesPanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notes:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildButtonPanel() {
    return _buildButtons();
  }

  Widget _buildTitle() {
    return const Text('Edit Transaction', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildSourceAmountField() {
    String? symbol;
    final data = widget.initialData;

    if (!isRoot) {
      final srid = data?.srId ?? 0;
      symbol = _cryptoController.getSymbol(srid);
    }

    return WidgetsFieldsAmount(
      title: 'Amount',
      initialValue: data?.srAmountTextRaw.replaceAll(',', ''),
      suffixText: symbol,
      enabled: _isActive,
      helperText: 'e.g., 1.5',
      onChanged: (value) {
        _srAmount = value;
      },
    );
  }

  Widget _buildSourceCryptoField() {
    final data = widget.initialData;

    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: data?.srId,
      enabled: isRoot,
      onSelected: (id) => setState(() => _selectedSrId = id),
    );
  }

  Widget _buildResultAmountField() {
    String? symbol;

    final data = widget.initialData;

    if (!isRoot && !_isActive) {
      final rrid = data?.rrId ?? 0;
      symbol = _cryptoController.getSymbol(rrid);
    }

    return WidgetsFieldsAmount(
      title: 'Amount',
      initialValue: data?.rrAmountTextRaw.replaceAll(',', ''),
      suffixText: symbol,
      enabled: isRoot || _isActive,
      helperText: 'e.g., 10.5',
      onChanged: (value) {
        _rrAmount = value;
      },
    );
  }

  Widget _buildResultCryptoField() {
    final data = widget.initialData;

    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: data?.rrId,
      enabled: !(!isRoot && !_isActive),
      onSelected: (id) => setState(() => _selectedRrId = id),
    );
  }

  Widget _buildNotesField() {
    final data = widget.initialData;

    return WidgetsFieldsTextarea(
      title: isRoot ? 'Purchase Notes' : 'Trading Notes',
      helperText: isRoot ? 'Edit purchase notes..' : 'Edit trading notes...',
      initialValue: data?.noteText,
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
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Wrap(
        direction: Axis.horizontal,
        runSpacing: 20,
        spacing: 10,
        runAlignment: WrapAlignment.center,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          WidgetsButtonsAction(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
          WidgetsButtonsAction(label: "Update", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
        ],
      ),
    );
  }
}

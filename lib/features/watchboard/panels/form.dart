import 'package:flutter/material.dart';

import '../../../../core/locator.dart';
import '../../../../core/utils.dart';
import '../../../../widgets/button.dart';
import '../../../../widgets/fields/amount.dart';
import '../../../../widgets/fields/crypto_search.dart';
import '../../../../widgets/panel.dart';
import '../../../app/exceptions.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import 'controller.dart';
import 'model.dart';

class PanelsForm extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final PanelsModel? initialData;
  final int? initialSrId;
  final double? initialSrAmount;
  final int? initialRrId;
  final String? linkedToTx;

  const PanelsForm({
    super.key,
    required this.onSave,
    this.initialData,
    this.initialSrId,
    this.initialSrAmount,
    this.initialRrId,
    this.linkedToTx,
  });

  @override
  State<PanelsForm> createState() => _PanelsFormState();
}

class _PanelsFormState extends State<PanelsForm> {
  PanelsController get _tixController => locator<PanelsController>();
  RatesController get _rateController => locator<RatesController>();
  CryptosController get _cryptosController => locator<CryptosController>();

  int? _selectedSrId;
  int? _selectedRrId;
  int? _digit;
  int? _order;

  String? _tid;
  String? _srAmountText;
  String? _sourceSymbol;

  double? _rate;

  final _formKey = GlobalKey<FormState>();

  String generateTid() => _tixController.generateId();

  @override
  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _tid = data?.tid ?? generateTid();
    _selectedSrId = widget.initialSrId ?? data?.srId;
    _selectedRrId = widget.initialRrId ?? data?.rrId;
    _digit = data?.digit ?? 6;
    _order = data?.order ?? _tixController.nextHighestOrder();
    _rate = data?.rate ?? -9999;

    _srAmountText = Utils.sanitizeNumber((widget.initialSrAmount ?? data?.srAmount ?? "").toString());

    if (widget.linkedToTx != null || (data != null && data.isLinked())) {
      _sourceSymbol = _selectedSrId != null ? _cryptosController.getSymbol(_selectedSrId!) : "";
    }
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final Map<String, dynamic> meta = {};
    final rate = _rateController.getStoredRate(_selectedSrId!, _selectedRrId!);

    if (rate == -9999) {
      _rateController.addQueue(_selectedSrId!, _selectedRrId!);
      meta["oldRate"] = rate;
    } else {
      _rate = rate;
    }

    if (widget.linkedToTx != null) {
      meta["txLink"] = widget.linkedToTx;
    }

    try {
      final model = PanelsModel(
        tid: _tid!,
        srAmount: double.tryParse(Utils.sanitizeNumber(_srAmountText ?? '0')) ?? 0.0,
        srId: _selectedSrId!,
        rrId: _selectedRrId!,
        digit: _digit!,
        rate: _rate ?? 0.0,
        order: _order,
        meta: meta,
      );

      await _tixController.update(model);
      widget.onSave?.call(null);
    } on ValidationException catch (e) {
      widget.onSave?.call(e);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                spacing: 24,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTitle(),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Row(
                          spacing: 16,
                          children: [
                            Expanded(child: _buildFromPanel()),
                            Expanded(child: _buildToPanel()),
                          ],
                        );
                      } else {
                        return Column(spacing: 24, children: [_buildFromPanel(), _buildToPanel()]);
                      }
                    },
                  ),

                  _buildPrecisionPanel(),

                  _buildButtonPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFromPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("From", style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            spacing: 16,
            children: [
              Flexible(
                flex: 3,
                child: WidgetsFieldsAmount(
                  title: 'Amount',
                  suffixText: _sourceSymbol,
                  enabled: widget.initialData == null ? widget.initialSrAmount == null : !widget.initialData!.isLinked(),
                  helperText: 'e.g., 65000',
                  initialValue: _srAmountText,
                  allowClean: _sourceSymbol == null,
                  allowCopy: _sourceSymbol == null,
                  onChanged: (v) => _srAmountText = Utils.sanitizeNumber(v),
                ),
              ),
              if (_sourceSymbol == null)
                Flexible(
                  flex: 2,
                  child: WidgetsFieldsCryptoSearch(
                    labelText: 'Coin',
                    enabled: widget.initialData == null ? widget.initialSrId == null : !widget.initialData!.isLinked(),
                    initialValue: _selectedSrId,
                    onSelected: (id) => setState(() => _selectedSrId = id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("To", style: TextStyle(fontWeight: FontWeight.w600)),
          WidgetsFieldsCryptoSearch(
            labelText: 'Target Coin',
            enabled: widget.initialData == null ? widget.initialRrId == null : !widget.initialData!.isLinked(),
            initialValue: _selectedRrId,
            onSelected: (id) => setState(() => _selectedRrId = id),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecisionPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Precision Digit", style: TextStyle(fontWeight: FontWeight.w600)),
          TextFormField(
            initialValue: _digit?.toString(),
            decoration: const InputDecoration(labelText: "Digit"),
            keyboardType: TextInputType.number,
            onChanged: (v) => _digit = int.tryParse(v),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonPanel() {
    return WidgetsPanel(padding: const EdgeInsets.all(12), child: _buildButtons());
  }

  Widget _buildTitle() {
    final isEdit = widget.initialData != null;
    return Text(isEdit ? 'Edit Watchboard' : 'New Watchboard', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtons() {
    final isEdit = widget.initialData != null;
    return Wrap(
      direction: Axis.horizontal,
      runSpacing: 14,
      spacing: 10,
      runAlignment: WrapAlignment.center,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        WidgetsButton(label: isEdit ? "Save" : "Create", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

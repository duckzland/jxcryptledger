import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/panel.dart';
import '../../app/exceptions.dart';
import 'controller.dart';
import 'model.dart';

class WatchersForm extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final WatchersModel? initialData;
  final int? initialSrId;
  final int? initialRrId;
  final double? initialRate;
  final String? linkedToTx;

  const WatchersForm({
    super.key,
    required this.onSave,
    this.initialData,
    this.initialSrId,
    this.initialRrId,
    this.initialRate,
    this.linkedToTx,
  });

  @override
  State<WatchersForm> createState() => _WatchersFormState();
}

class _WatchersFormState extends State<WatchersForm> {
  WatchersController get _controller => locator<WatchersController>();

  String? _wid;
  int? _selectedSrId;
  int? _selectedRrId;
  int? _sent;
  String? _operator;
  String? _rateAmount;
  String? _limitCount;
  String? _durationMinutes;
  String? _message;

  final _formKey = GlobalKey<FormState>();

  String generateWid() => _controller.generateWid();

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _wid = data?.wid ?? generateWid();
    _selectedSrId = data?.srId;
    _selectedRrId = data?.rrId;
    _sent = 0;
    _operator = data?.operator.toString() ?? WatchersOperator.greaterThan.index.toString();
    _rateAmount = Utils.sanitizeNumber(data?.rates.toString() ?? "");
    _limitCount = Utils.sanitizeNumber(data?.limit.toString() ?? "3");
    _durationMinutes = Utils.sanitizeNumber(data?.duration.toString() ?? "60");
    _message = data?.message ?? "";

    if (widget.initialSrId != null) {
      _selectedSrId = widget.initialSrId;
    }

    if (widget.initialRrId != null) {
      _selectedRrId = widget.initialRrId;
    }

    if (widget.initialRate != null) {
      _rateAmount = Utils.sanitizeNumber(widget.initialRate.toString());
    }
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final model = WatchersModel(
        wid: _wid!,
        srId: _selectedSrId!,
        rrId: _selectedRrId!,
        rates: double.tryParse(Utils.sanitizeNumber(_rateAmount ?? "0")) ?? 0,
        sent: _sent!,
        operator: int.tryParse(_operator ?? "2") ?? 2,
        limit: int.tryParse(_limitCount ?? "0") ?? 0,
        duration: int.tryParse(_durationMinutes ?? "0") ?? 0,
        message: _message!,
        timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        meta: widget.linkedToTx != null ? {"txLink": widget.linkedToTx} : {},
      );

      await _controller.update(model);
      widget.onSave?.call(null);
    } on ValidationException catch (e) {
      // TODO: Improve this by analyzing the error code and set the form field error state!
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
        constraints: const BoxConstraints(minWidth: 1600, maxWidth: 1600, minHeight: 200, maxHeight: 800),
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
                          Expanded(
                            child: WidgetsPanel(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("From", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  WidgetsFieldsCryptoSearch(
                                    labelText: 'Coin',
                                    initialValue: _selectedSrId,
                                    enabled: widget.initialData == null ? widget.initialSrId == null : !widget.initialData!.isLinked(),
                                    onSelected: (id) => setState(() => _selectedSrId = id),
                                  ),
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
                                  const Text("To", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  WidgetsFieldsCryptoSearch(
                                    labelText: 'Coin',
                                    initialValue: _selectedRrId,
                                    enabled: widget.initialData == null ? widget.initialSrId == null : !widget.initialData!.isLinked(),
                                    onSelected: (id) => setState(() => _selectedRrId = id),
                                  ),
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
                                  const Text("Operator", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    initialValue: _operator,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      labelText: "Operator",
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: "0", child: Text("Rate = target rate")),
                                      DropdownMenuItem(value: "1", child: Text("Rate < target rate")),
                                      DropdownMenuItem(value: "2", child: Text("Rate > target rate")),
                                    ],
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _operator = newValue!;
                                      });
                                    },
                                  ),
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
                                  const Text("Target Rate", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  WidgetsFieldsAmount(
                                    title: 'Rate',
                                    helperText: 'e.g., 65000',
                                    initialValue: _rateAmount,
                                    onChanged: (value) => _rateAmount = value,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: WidgetsPanel(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Limit", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    initialValue: _limitCount,
                                    decoration: const InputDecoration(labelText: "Times to send"),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => _limitCount = v,
                                  ),
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
                                  const Text("Retry Duration", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    initialValue: _durationMinutes,
                                    decoration: const InputDecoration(labelText: "Minutes", suffixText: "Minutes"),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => _durationMinutes = v,
                                  ),
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
                            const Text("Message", style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            WidgetsFieldsTextarea(
                              title: 'Notification Message',
                              helperText: 'Enter message..',
                              initialValue: _message,
                              onChanged: (value) => _message = value,
                            ),
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
      ),
    );
  }

  Widget _buildTitle() {
    return const Text('New Watcher', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtons() {
    final isEdit = widget.initialData != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
        const SizedBox(width: 12),
        WidgetsButton(label: isEdit ? "Save" : "Create", initialState: WidgetsButtonActionState.action, onPressed: (_) => _handleSave()),
      ],
    );
  }
}

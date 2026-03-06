import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/textarea.dart';
import '../../app/exceptions.dart';
import '../cryptos/controller.dart';
import 'controller.dart';
import 'model.dart';

class WatchersForm extends StatefulWidget {
  final void Function(Object? error)? onSave;
  final WatchersModel? initialData;

  const WatchersForm({super.key, required this.onSave, this.initialData});

  @override
  State<WatchersForm> createState() => _WatchersFormState();
}

class _WatchersFormState extends State<WatchersForm> {
  WatchersController get _controller => locator<WatchersController>();
  CryptosController get _cryptosController => locator<CryptosController>();

  int? _selectedSrId;
  int? _selectedRrId;
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

    _selectedSrId = data?.srId;
    _selectedRrId = data?.rrId;
    _rateAmount = data?.rates.toString();
    _rateAmount = data?.rates.toString() ?? "0";
    _limitCount = data?.limit.toString() ?? "3";
    _durationMinutes = data?.duration.toString() ?? "60";
    _message = data?.message ?? "";
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final isEdit = widget.initialData != null;
      final old = widget.initialData;

      final sourceSymbol = _cryptosController.getSymbol(_selectedSrId ?? 0) ?? "";
      final targetSymbol = _cryptosController.getSymbol(_selectedRrId ?? 0) ?? "";

      final craftedMessage = "$sourceSymbol to $targetSymbol reached $_rateAmount.";

      final message = (_message == null || _message!.trim().isEmpty) ? craftedMessage : _message!;

      final model = WatchersModel(
        wid: isEdit ? old!.wid : generateWid(),
        srId: _selectedSrId ?? 0,
        rrId: _selectedRrId ?? 0,
        rates: double.tryParse(Utils.sanitizeNumber(_rateAmount ?? "0")) ?? 0,
        sent: isEdit ? old!.sent : 0,
        limit: int.tryParse(_limitCount ?? "0") ?? 0,
        duration: int.tryParse(_durationMinutes ?? "0") ?? 0,
        message: message,
        timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
      );

      if (isEdit) {
        await _controller.update(model);
      } else {
        await _controller.add(model);
      }

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
                                    decoration: const InputDecoration(labelText: "Minutes"),
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

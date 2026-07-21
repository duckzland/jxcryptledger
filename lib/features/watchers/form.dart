import 'package:flutter/material.dart';

import '../../../core/utils.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../app/exceptions.dart';
import '../../core/runtime/locator.dart';
import '../../mixins/rateable.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/header.dart';
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

class _WatchersFormState extends State<WatchersForm> with MixinsRateable<WatchersForm> {
  WatchersController get _controller => locator<WatchersController>();

  String? _wid;
  int? _sent;
  String? _operator;
  String? _limitCount;
  String? _durationMinutes;
  String? _message;

  final _formKey = GlobalKey<FormState>();

  String generateWid() => _controller.generateId();

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    rateableSource = data?.srId;
    rateableTarget = data?.rrId;
    rateableAmount = Utils.sanitizeNumber(data?.rates.toString() ?? "");

    _wid = data?.wid ?? generateWid();
    _sent = 0;
    _operator = data?.operator.toString() ?? WatchersOperator.greaterThan.index.toString();
    _limitCount = Utils.sanitizeNumber(data?.limit.toString() ?? "3");
    _durationMinutes = Utils.sanitizeNumber(data?.duration.toString() ?? "60");
    _message = data?.message ?? "";

    if (widget.initialSrId != null) {
      rateableSource = widget.initialSrId;
    }

    if (widget.initialRrId != null) {
      rateableTarget = widget.initialRrId;
    }

    if (widget.initialRate != null && widget.initialRate! > 0) {
      rateableAmount = Utils.sanitizeNumber(widget.initialRate.toString());
    }
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
              spacing: 30,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitle(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Column(
                        spacing: 24,
                        children: [
                          Row(
                            spacing: 24,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildFromPanel()),
                              Expanded(child: _buildToPanel()),
                              Expanded(child: _buildOpsPanel()),
                              Expanded(child: _buildTargetPanel()),
                            ],
                          ),
                          Row(
                            spacing: 24,
                            children: [
                              Expanded(child: _buildLimitPanel()),
                              Expanded(child: _buildDurationPanel()),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Column(spacing: 30, children: [_buildFromPanel(), _buildToPanel(), _buildOpsPanel(), _buildTargetPanel()]);
                    }
                  },
                ),

                _buildMessagePanel(),
                _buildButtonPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFromPanel() {
    return WidgetsHeader(
      subtitle: "From:",
      subtitleFontSize: 13,
      spacing: 10,
      child: WidgetsFieldsCryptoSearch(
        labelText: 'Coin',
        initialValue: rateableSource,
        enabled: widget.initialData == null ? widget.initialSrId == null : !widget.initialData!.isLinked,
        onSelected: (id) => setState(() => rateableSource = id),
      ),
    );
  }

  Widget _buildToPanel() {
    return WidgetsHeader(
      subtitle: "To:",
      subtitleFontSize: 13,
      spacing: 10,
      child: WidgetsFieldsCryptoSearch(
        labelText: 'Coin',
        initialValue: rateableTarget,
        enabled: widget.initialData == null ? widget.initialSrId == null : !widget.initialData!.isLinked,
        onSelected: (id) => setState(() => rateableTarget = id),
      ),
    );
  }

  Widget _buildOpsPanel() {
    return WidgetsHeader(
      subtitle: "Operator:",
      subtitleFontSize: 13,
      spacing: 10,
      child: DropdownMenu<String>(
        initialSelection: _operator,
        requestFocusOnTap: false,
        label: const Text("Operator"),
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: const [
          DropdownMenuEntry<String>(value: "0", label: "Rate = target rate"),
          DropdownMenuEntry<String>(value: "1", label: "Rate < target rate"),
          DropdownMenuEntry<String>(value: "2", label: "Rate > target rate"),
        ],
        onSelected: (String? newValue) {
          if (newValue == null) return;
          setState(() {
            _operator = newValue;
          });
        },
      ),
    );
  }

  Widget _buildTargetPanel() {
    return WidgetsHeader(
      subtitle: "Target Rate:",
      subtitleFontSize: 13,
      spacing: 10,
      child: WidgetsFieldsAmount(
        title: 'Rate',
        helperText: 'e.g., 65000',
        initialValue: rateableAmount,
        allowReverse: true,
        allowRate: rateableAllow,
        onRetrievingRate: (void Function(String value, String helperText) updateState) {
          // Store the callback to act as promise contract!
          rateableStateUpdater = updateState;
          rateableStateUpdater?.call("", "Retrieving rate...");
          rateableGetRate();
        },
        onChanged: (value) {
          // Nullify the promise contract!
          rateableStateUpdater = null;
          rateableAmount = value;
        },
      ),
    );
  }

  Widget _buildLimitPanel() {
    return WidgetsHeader(
      subtitle: "Limit:",
      subtitleFontSize: 13,
      spacing: 10,
      child: TextFormField(
        initialValue: _limitCount,
        decoration: const InputDecoration(labelText: "Times to send"),
        keyboardType: TextInputType.number,
        onChanged: (v) => _limitCount = v,
      ),
    );
  }

  Widget _buildDurationPanel() {
    return WidgetsHeader(
      subtitle: "Retry Duration:",
      subtitleFontSize: 13,
      spacing: 10,
      child: TextFormField(
        initialValue: _durationMinutes,
        decoration: const InputDecoration(labelText: "Minutes", suffixText: "Minutes"),
        keyboardType: TextInputType.number,
        onChanged: (v) => _durationMinutes = v,
      ),
    );
  }

  Widget _buildMessagePanel() {
    return WidgetsHeader(
      subtitle: "Message:",
      subtitleFontSize: 13,
      spacing: 10,
      child: WidgetsFieldsTextarea(
        title: 'Notification Message',
        helperText: 'Enter message..',
        initialValue: _message,
        onChanged: (value) => _message = value,
      ),
    );
  }

  Widget _buildButtonPanel() {
    return _buildButtons();
  }

  Widget _buildTitle() {
    final isEdit = widget.initialData != null;
    return Text(isEdit ? 'Edit Rate Watcher' : 'New Rate Watcher', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtons() {
    final isEdit = widget.initialData != null;
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Wrap(
        direction: Axis.horizontal,
        runSpacing: 14,
        spacing: 10,
        runAlignment: WrapAlignment.center,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          WidgetsButtonsAction(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
          WidgetsButtonsAction(
            label: isEdit ? "Save" : "Create",
            initialState: WidgetsButtonActionState.action,
            onPressed: (_) => _handleSave(),
          ),
        ],
      ),
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final model = WatchersModel(
        wid: _wid!,
        srId: rateableSource!,
        rrId: rateableTarget!,
        rates: double.tryParse(Utils.sanitizeNumber(rateableAmount ?? "0")) ?? 0,
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
      widget.onSave?.call(e);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }
}

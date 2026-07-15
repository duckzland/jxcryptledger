import 'package:flutter/material.dart';

import '../../../widgets/fields/textarea.dart';
import '../../app/theme.dart';
import '../../app/exceptions.dart';
import '../../core/runtime/locator.dart';
import '../../widgets/buttons/action.dart';
import '../../mixins/rateable.dart';
import '../../system/settings/controller.dart';
import '../transactions/controller.dart';
import '../watchboard/panels/controller.dart';
import '../watchers/controller.dart';
import 'controller.dart';
import 'model.dart';

class ArchivesForm extends StatefulWidget {
  final void Function(Object? error)? onSave;

  const ArchivesForm({super.key, required this.onSave});

  @override
  State<ArchivesForm> createState() => _ArchivesFormState();
}

class _ArchivesFormState extends State<ArchivesForm> with MixinsRateable<ArchivesForm> {
  ArchivesController get _controller => locator<ArchivesController>();

  final TransactionsController _txController = locator<TransactionsController>();
  final PanelsController _pxController = locator<PanelsController>();
  final WatchersController _wxController = locator<WatchersController>();
  final SettingsController _sxController = locator<SettingsController>();

  String? _type;
  String? _notes;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1600),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _canArchive()
              ? Form(
                  key: _formKey,
                  child: Column(
                    spacing: 30,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_buildTitle(), _buildTypePanel(), _buildNotesPanel(), _buildButtonPanel()],
                  ),
                )
              : Center(child: Text("No valid data that can be archived.")),
        ),
      ),
    );
  }

  Widget _buildTypePanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Data Type", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        DropdownMenu<String>(
          initialSelection: _type,
          requestFocusOnTap: false,
          expandedInsets: EdgeInsets.zero,
          label: const Text("Data Type"),
          dropdownMenuEntries: [
            if (_txController.items.isNotEmpty) const DropdownMenuEntry<String>(value: "transactions", label: "Transactions Data"),
            if (_pxController.items.isNotEmpty) const DropdownMenuEntry<String>(value: "watchboards", label: "Watchboards Data"),
            if (_wxController.items.isNotEmpty) const DropdownMenuEntry<String>(value: "watchers", label: "Rate Watchers Data"),
            if (_sxController.items.isNotEmpty) const DropdownMenuEntry<String>(value: "settings", label: "Settings Data"),
          ],
          onSelected: (String? newValue) {
            if (newValue == null) return;
            setState(() {
              _type = newValue;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotesPanel() {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notes", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        WidgetsFieldsTextarea(title: 'Notes', helperText: 'Enter notes..', maxLines: 1, onChanged: (value) => _notes = value),
      ],
    );
  }

  Widget _buildButtonPanel() {
    return _buildButtons();
  }

  Widget _buildTitle() {
    return const Text('Create New Archive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtons() {
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
            label: "Create",
            initialState: WidgetsButtonActionState.action,
            evaluator: (s) {
              if (_canArchive()) {
                s.action();
              } else {
                s.disable();
              }
            },
            onPressed: (_) => _handleSave(),
          ),
        ],
      ),
    );
  }

  bool _canArchive() {
    return _txController.items.isNotEmpty ||
        _pxController.items.isNotEmpty ||
        _wxController.items.isNotEmpty ||
        _sxController.items.isNotEmpty;
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final type = ArchivesDataType.values.byName(_type ?? "");
      final data = await _controller.populateData(type);

      final model = ArchivesModel(
        aid: _controller.generateId(),
        type: type.index,
        data: data,
        timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        meta: {"notes": _notes ?? ""},
      );

      await _controller.add(model);
      widget.onSave?.call(null);
    } on ValidationException catch (e) {
      widget.onSave?.call(e);
    } catch (e) {
      widget.onSave?.call(e);
    }
  }
}

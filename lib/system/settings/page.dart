import 'package:flutter/material.dart';

import '../../core/runtime/locator.dart';
import '../../core/scrollto.dart';
import '../../mixins/action_bar.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/dialogs/export.dart';
import '../../widgets/dialogs/import.dart';
import '../../widgets/dialogs/reset.dart';
import '../../widgets/panel.dart';
import '../../widgets/notify.dart';
import 'controller.dart';
import 'keys.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with MixinsActionBar<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late Map<SettingKey, dynamic> _buffer = {};
  SettingsController get _controller => locator<SettingsController>();

  final scrollToUtil = ScrollTo('sx-offset');

  int _buildCount = 0;

  bool _isDirty() {
    final userKeys = SettingKey.values.where((k) => k.isUserEditable);
    for (var key in userKeys) {
      if (!_buffer.containsKey(key)) {
        continue;
      }
      final current = _buffer[key];
      final original = _controller.getByKey<dynamic>(key);
      if (current != original) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);

    actionbarRegister("Settings");
  }

  @override
  Widget actionbarLeftAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Wrap(
              spacing: 4,
              children: [
                WidgetsDialogsImport(
                  key: const Key("import-button-batch"),
                  tooltip: "Import settings to database",
                  showDialogBeforeImport: true,
                  onImport: (String json) async {
                    await _controller.importDatabase(json);
                  },
                  evaluator: (s) {},
                ),
                WidgetsDialogsExport(
                  key: const Key("export-button-batch"),
                  tooltip: "Export settings from database",
                  suggestedPrefix: "settings_",
                  onExport: _controller.exportDatabase,
                  isEmpty: _controller.isEmpty,
                ),
                WidgetsDialogsReset(
                  key: const Key("reset-button-batch"),
                  tooltip: "Delete all settings data",
                  dialogTitle: "Delete All Settings",
                  dialogMessage:
                      "This will delete all settings data.\n"
                      "This action cannot be undone.",
                  onWipe: () {
                    return _controller.clear();
                  },
                  isEmpty: _controller.isEmpty,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editableKeys = SettingKey.values.where((k) => k.isUserEditable).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1024),
        child: Form(
          key: _formKey,
          child: ListView.separated(
            controller: scrollToUtil.controller,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: editableKeys.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              return WidgetsPanel(child: _buildItem(index, editableKeys));
            },
          ),
        ),
      ),
    );
  }

  void _onControllerChange() {
    setState(() {
      _buildCount++;
    });
  }

  Widget _buildItem(int index, List<SettingKey> editableKeys) {
    if (index == editableKeys.length) {
      return Wrap(
        direction: Axis.horizontal,
        runSpacing: 20,
        spacing: 10,
        runAlignment: WrapAlignment.center,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [_buildResetButton(editableKeys), _buildSaveButton()],
      );
    }

    final key = editableKeys[index];
    return _buildSettingField(key);
  }

  Widget _buildSettingField(SettingKey key) {
    final dynamic current = _buffer.containsKey(key) ? _buffer[key] : _controller.getByKey<dynamic>(key);

    Widget field;

    switch (key.type) {
      case SettingType.boolean:
        final boolVal = (current is bool) ? current : false;
        field = Row(
          children: [
            Switch(
              key: ValueKey("${key.name}-$_buildCount"),
              value: boolVal,
              onChanged: (v) {
                setState(() {
                  _buffer[key] = v;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(boolVal ? 'Enabled' : 'Disabled'),
          ],
        );

        break;

      case SettingType.list:
        field = TextFormField(
          key: ValueKey("${key.name}-$_buildCount"),
          initialValue: (current is List) ? current.join(',') : (current?.toString() ?? ''),
          decoration: InputDecoration(
            hintText: key.hintText.isNotEmpty ? key.hintText : "Enter ${key.label} (comma separated)...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          maxLines: null,
          onChanged: (val) {
            setState(() {
              _buffer[key] = val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            });
          },
        );

        break;

      case SettingType.integer:
        field = TextFormField(
          key: ValueKey("${key.name}-$_buildCount"),
          initialValue: current?.toString() ?? '',
          decoration: InputDecoration(
            hintText: key.hintText.isNotEmpty ? key.hintText : "Enter ${key.label}...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (key.required && (value == null || value.isEmpty)) return "This field is required";
            if (value != null && int.tryParse(value) == null) return "Must be a valid number";
            return null;
          },
          onChanged: (val) {
            setState(() {
              _buffer[key] = int.tryParse(val);
            });
          },
        );

        break;

      default:
        field = TextFormField(
          key: ValueKey("${key.name}-$_buildCount"),
          initialValue: current?.toString() ?? _controller.getByKey(key),
          decoration: InputDecoration(
            hintText: key.hintText.isNotEmpty ? key.hintText : "Enter ${key.label}...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          keyboardType: TextInputType.text,
          validator: (value) {
            if (key.required && (value == null || value.isEmpty)) {
              return "This field is required";
            }

            if (key.validator != null) {
              final err = key.validator!(value ?? "");
              if (err != null) return err;
            }

            return null;
          },
          onChanged: (val) {
            setState(() {
              _buffer[key] = val;
            });
          },
        );
    }

    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        field,
      ],
    );
  }

  Widget _buildSaveButton() {
    return WidgetsButtonsAction(
      key: const ValueKey('settings-save-button'),
      label: "Save Changes",
      initialState: WidgetsButtonActionState.action,
      evaluator: (s) {
        if (!_isDirty()) {
          s.disable();
        } else {
          s.action();
        }
      },
      onPressed: (s) async {
        s.progress();

        if (_formKey.currentState!.validate()) {
          final savedKeys = _buffer.keys.toList();
          for (var key in savedKeys) {
            final newValue = _buffer[key];
            await _controller.updateByKey(key, newValue);
          }

          setState(() {
            for (var k in savedKeys) {
              _buffer.remove(k);
            }
            _buildCount++;
          });

          if (!mounted) return;
          widgetsNotifySuccess("Securely saved to vault");
        }

        s.reset();
      },
    );
  }

  Widget _buildResetButton(List<SettingKey> editableKeys) {
    return WidgetsButtonsAction(
      key: const ValueKey('settings-reset-button'),
      initialState: WidgetsButtonActionState.error,
      label: "Reset to Default",
      onPressed: (s) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Reset Settings"),
              content: const Text("Are you sure you want to reset all settings to default values?"),
              actions: [
                WidgetsButtonsAction(
                  label: "Cancel",
                  onPressed: (s) {
                    Navigator.pop(context, false);
                  },
                ),
                WidgetsButtonsAction(
                  initialState: WidgetsButtonActionState.error,
                  label: "Reset",
                  onPressed: (s) => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );

        if (confirmed != true) return;

        s.progress();

        Map<SettingKey, dynamic> newBuff = {};
        for (var key in editableKeys) {
          final def = key.defaultValue;
          await _controller.updateByKey(key, def);
          newBuff[key] = def;
        }

        setState(() {
          _buildCount++;
          _buffer = newBuff;
        });

        if (!mounted) return;
        widgetsNotifySuccess("Settings reset to default");

        s.error();
      },
    );
  }
}

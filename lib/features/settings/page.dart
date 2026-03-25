import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/panel.dart';
import '../../widgets/notify.dart';
import 'controller.dart';
import 'keys.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late Map<SettingKey, dynamic> _buffer = {};
  late final SettingsController _controller;

  int _buildCount = 0;

  bool _isDirty() {
    final userKeys = SettingKey.values.where((k) => k.isUserEditable);
    for (var key in userKeys) {
      final current = _buffer[key];
      final original = _controller.get<dynamic>(key);
      if (current != original) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller = locator<SettingsController>();
    final userKeys = SettingKey.values.where((k) => k.isUserEditable);

    for (var key in userKeys) {
      _buffer[key] = _controller.get<dynamic>(key);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call("Settings");
    });
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
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        TextFormField(
          key: ValueKey("${key.name}-$_buildCount"),
          initialValue: _buffer[key]?.toString(),
          decoration: InputDecoration(
            hintText: key.hintText.isNotEmpty ? key.hintText : "Enter ${key.label}...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          keyboardType: key.type == SettingType.integer ? TextInputType.number : TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "This field is required";
            }

            if (key.validator != null) {
              final err = key.validator!(value);
              if (err != null) return err;
            }

            if (key.type == SettingType.integer && int.tryParse(value) == null) {
              return "Must be a valid number";
            }

            return null;
          },
          onChanged: (val) {
            setState(() {
              _buffer[key] = key.type == SettingType.integer ? int.tryParse(val) : val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return WidgetsButton(
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
          for (var key in _buffer.keys) {
            final newValue = _buffer[key];
            await _controller.update(key, newValue);
          }

          if (!mounted) return;
          widgetsNotifySuccess("Securely saved to vault");
        }

        s.reset();
      },
    );
  }

  Widget _buildResetButton(List<SettingKey> editableKeys) {
    return WidgetsButton(
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
                WidgetsButton(
                  label: "Cancel",
                  onPressed: (s) {
                    Navigator.pop(context, false);
                  },
                ),
                WidgetsButton(initialState: WidgetsButtonActionState.error, label: "Reset", onPressed: (s) => Navigator.pop(context, true)),
              ],
            );
          },
        );

        if (confirmed != true) return;

        s.progress();

        Map<SettingKey, dynamic> newBuff = {};
        for (var key in editableKeys) {
          final def = key.defaultValue;
          await _controller.update(key, def);
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

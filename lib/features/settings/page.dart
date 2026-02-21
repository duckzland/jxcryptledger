import 'package:flutter/material.dart';
import 'package:jxcryptledger/app/snackbar.dart';

import '../../app/button.dart';
import '../../core/locator.dart';
import 'controller.dart';
import 'repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<SettingKey, dynamic> _buffer = {};
  late final SettingsController _controller;
  
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
  }

  @override
  Widget build(BuildContext context) {
    final editableKeys = SettingKey.values.where((k) => k.isUserEditable).toList();

    return Form(
      key: _formKey,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: editableKeys.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1024),
              child: _buildItem(index, editableKeys),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(int index, List<SettingKey> editableKeys) {
    if (index == editableKeys.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [_buildResetButton(editableKeys), const SizedBox(width: 12), _buildSaveButton()],
        ),
      );
    }

    final key = editableKeys[index];
    return _buildSettingField(key);
  }

  Widget _buildSettingField(SettingKey key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _buffer[key]?.toString(),
          decoration: InputDecoration(
            hintText: key.hintText.isNotEmpty ? key.hintText : "Enter ${key.label}...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: key.type == SettingType.integer ? TextInputType.number : TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) return "This field is required";

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
    return AppButton(
      label: "Save Changes",
      evaluator: (s) {
        if (!_isDirty()) {
          s.disable();
        } else {
          s.normal();
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
          appShowSuccess(context, "Securely saved to vault");
        }

        s.reset();
      },
    );
  }

  Widget _buildResetButton(List<SettingKey> editableKeys) {
    return AppButton(
      initialState: AppActionState.error,
      label: "Reset to Default",
      onPressed: (s) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Reset Settings"),
              content: const Text("Are you sure you want to reset all settings to default values?"),
              actions: [
                AppButton(
                  label: "Cancel",
                  onPressed: (s) {
                    Navigator.pop(context, false);
                  },
                ),
                AppButton(
                  initialState: AppActionState.error,
                  label: "Reset",
                  onPressed: (s) => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );

        if (confirmed != true) return;

        s.progress();

        for (var key in editableKeys) {
          final def = key.defaultValue;
          await _controller.update(key, def);
          _buffer[key] = def;
        }

        setState(() {});

        if (!mounted) return;
        appShowSuccess(context, "Settings reset to default");

        s.error(); // return to error theme
      },
    );
  }
}

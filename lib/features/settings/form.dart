import 'package:flutter/material.dart';
import 'package:jxcryptledger/app/snackbar.dart';

import '../../app/button.dart';
import '../../app/theme.dart';
import 'controller.dart';
import 'repository.dart';

class SettingsForm extends StatefulWidget {
  final SettingsController controller;

  const SettingsForm({super.key, required this.controller});

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<SettingKey, dynamic> _buffer = {};

  @override
  void initState() {
    super.initState();
    final userKeys = SettingKey.values.where((k) => k.isUserEditable);

    for (var key in userKeys) {
      _buffer[key] = widget.controller.get<dynamic>(key);
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
        separatorBuilder: (_, __) => const SizedBox(height: 24),
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
            _buffer[key] = key.type == SettingType.integer ? int.tryParse(val) : val;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return appButton(
      label: "Save Changes",
      onPressed: () async {
        if (_formKey.currentState!.validate()) {
          for (var key in _buffer.keys) {
            final newValue = _buffer[key];
            await widget.controller.update(key, newValue);
          }

          if (!mounted) return;
          appShowSuccess(context, "Securely saved to vault");
        }
      },
    );
  }

  Widget _buildResetButton(List<SettingKey> editableKeys) {
    return appButton(
      label: "Reset to Default",
      background: AppTheme.error,
      foreground: AppTheme.text,
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Reset Settings"),
              content: const Text("Are you sure you want to reset all settings to default values?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reset")),
              ],
            );
          },
        );

        if (confirmed != true) return;

        for (var key in editableKeys) {
          final def = key.defaultValue;
          await widget.controller.update(key, def);
          _buffer[key] = def;
        }

        setState(() {});

        if (!mounted) return;
        appShowSuccess(context, "Settings reset to default");
      },
    );
  }
}

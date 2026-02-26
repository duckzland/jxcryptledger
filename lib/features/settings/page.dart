import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jxcryptledger/widgets/notify.dart';

import '../../app/layout.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/panel.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLayout.setTitle?.call("Settings");
    });
  }

  @override
  Widget build(BuildContext context) {
    final editableKeys = SettingKey.values.where((k) => k.isUserEditable).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Form(
        key: _formKey,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: editableKeys.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: WidgetsPanel(child: _buildItem(index, editableKeys)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(int index, List<SettingKey> editableKeys) {
    if (index == editableKeys.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCancelButton(),
            const SizedBox(width: 12),
            _buildResetButton(editableKeys),
            const SizedBox(width: 12),
            _buildSaveButton(),
          ],
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
    return WidgetButton(
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
          widgetsNotifySuccess(context, "Securely saved to vault");
        }

        s.reset();
      },
    );
  }

  Widget _buildResetButton(List<SettingKey> editableKeys) {
    return WidgetButton(
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
                WidgetButton(
                  label: "Cancel",
                  onPressed: (s) {
                    Navigator.pop(context, false);
                  },
                ),
                WidgetButton(
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

        for (var key in editableKeys) {
          final def = key.defaultValue;
          await _controller.update(key, def);
          _buffer[key] = def;
        }

        setState(() {});

        if (!mounted) return;
        widgetsNotifySuccess(context, "Settings reset to default");

        s.error(); // return to error theme
      },
    );
  }

  Widget _buildCancelButton() {
    return WidgetButton(
      label: "Cancel",
      initialState: WidgetsButtonActionState.action,
      onPressed: (s) {
        if (!mounted) return;

        if (context.canPop()) {
          context.pop();
        } else {
          context.go("/transactions");
        }
      },
    );
  }
}

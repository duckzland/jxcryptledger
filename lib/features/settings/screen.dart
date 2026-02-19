import 'package:flutter/material.dart';
import 'controller.dart';
import 'repository.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<SettingKey, dynamic> _buffer = {};

  @override
  void initState() {
    super.initState();
    // 1. Get ONLY the keys the user is allowed to see/edit
    final userKeys = SettingKey.values.where((k) => k.isUserEditable);

    for (var key in userKeys) {
      _buffer[key] = widget.controller.get<dynamic>(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter keys allowed for user editing
    final editableKeys = SettingKey.values
        .where((k) => k.isUserEditable)
        .toList();

    return Form(
      key: _formKey,
      child: ListView.separated(
        // Padding is now handled by AppLayout, so we keep this 0 or minimal
        padding: EdgeInsets.zero,
        itemCount: editableKeys.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          if (index == editableKeys.length) {
            return _buildSaveButton();
          }

          final key = editableKeys[index];
          return _buildSettingField(key);
        },
      ),
    );
  }

  Widget _buildSettingField(SettingKey key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _buffer[key]?.toString(),
          decoration: InputDecoration(
            hintText: "Enter ${key.label}...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          keyboardType: key.type == SettingType.integer
              ? TextInputType.number
              : TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) return "This field is required";
            if (key.type == SettingType.integer &&
                int.tryParse(value) == null) {
              return "Must be a valid number";
            }
            return null;
          },
          onChanged: (val) {
            _buffer[key] = key.type == SettingType.integer
                ? int.tryParse(val)
                : val;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      // Center the button horizontally
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 2,
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              // 2. Loop only over what is actually in our form buffer
              for (var key in _buffer.keys) {
                final newValue = _buffer[key];
                await widget.controller.update(key, newValue);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Securely saved to vault")),
                );
              }
            }
          },
          child: const Text("Save Changes"),
        ),
      ),
    );
  }
}

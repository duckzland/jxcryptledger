import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/button.dart';
import 'controller.dart';

class UnlockPage extends StatefulWidget {
  final UnlockController controller;

  const UnlockPage({super.key, required this.controller});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
    widget.controller.init();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool showPassword = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final isFirstRun = widget.controller.isFirstRun;

    return Scaffold(
      body: Center(child: SizedBox(width: 300, child: isFirstRun ? _buildFirstRunUI() : _buildUnlockUI())),
    );
  }

  Widget _buildFirstRunUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Welcome!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Create a password to secure your vault.", textAlign: TextAlign.center),
        const SizedBox(height: 20),

        TextField(
          controller: _password,
          obscureText: !showPassword,
          decoration: const InputDecoration(labelText: "Password"),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _confirm,
          obscureText: !showPassword,
          decoration: const InputDecoration(labelText: "Confirm Password"),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(value: showPassword, onChanged: (v) => setState(() => showPassword = v!)),
            const Text("Show password"),
          ],
        ),

        if (error != null) ...[const SizedBox(height: 8), Text(error!, style: const TextStyle(color: Colors.red))],

        const SizedBox(height: 20),

        AppButton(
          label: "Create Vault",
          evaluator: (s) {
            if (_password.text.isEmpty || _confirm.text.isEmpty || _password.text != _confirm.text) {
              s.disable();
            } else {
              s.normal();
            }
          },
          onPressed: (s) async {
            if (_password.text.isEmpty) {
              setState(() => error = "Password cannot be empty");
              return;
            }

            if (_password.text != _confirm.text) {
              setState(() => error = "Passwords do not match");
              return;
            }

            s.progress();

            final ok = await widget.controller.unlock(_password.text);

            if (!mounted) return;

            if (ok) {
              s.active();
              context.go("/transactions");
            } else {
              s.error();
            }
          },
        ),
      ],
    );
  }

  Widget _buildUnlockUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Please enter password to unlock", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),

        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: "Password", errorText: error),
        ),

        const SizedBox(height: 20),

        AppButton(
          label: "Unlock",
          evaluator: (s) {
            if (_password.text.isEmpty) {
              s.disable();
            } else {
              s.normal();
            }
          },
          onPressed: (s) async {
            final ok = await widget.controller.unlock(_password.text);
            if (ok) {
              if (!mounted) return;
              context.go("/transactions");
            } else {
              setState(() => error = "Invalid password");
            }
          },
        ),
      ],
    );
  }
}

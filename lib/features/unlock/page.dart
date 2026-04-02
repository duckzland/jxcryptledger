import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/version.dart';
import '../../widgets/button.dart';
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
      body: Stack(
        children: [
          Center(child: SizedBox(width: 300, child: isFirstRun ? _buildFirstRunUI() : _buildUnlockUI())),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('v${AppVersion.full}', style: const TextStyle(fontSize: 12, color: AppTheme.textInactive)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstRunUI() {
    return Column(
      spacing: 20,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          spacing: 8,
          children: [
            const Text("Welcome!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Create a password to secure your vault.", textAlign: TextAlign.center),
          ],
        ),

        Column(
          spacing: 12,
          children: [
            TextField(
              controller: _password,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            TextField(
              controller: _confirm,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(value: showPassword, onChanged: (v) => setState(() => showPassword = v!)),
                const Text("Show password"),
              ],
            ),

            if (error != null)
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),

        WidgetsButton(
          label: "Create Vault",
          initialState: WidgetsButtonActionState.action,
          evaluator: (s) {
            if (_password.text.isEmpty || _confirm.text.isEmpty || _password.text != _confirm.text) {
              s.disable();
            } else {
              s.action();
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
      spacing: 20,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Please enter password to unlock", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "Password",
            errorText: error,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),

        WidgetsButton(
          label: "Unlock",
          initialState: WidgetsButtonActionState.action,
          evaluator: (s) {
            if (_password.text.isEmpty) {
              s.disable();
            } else {
              s.action();
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

import 'package:flutter/material.dart';
import 'controller.dart';
import 'package:go_router/go_router.dart';

class UnlockPage extends StatefulWidget {
  final UnlockController controller;

  const UnlockPage({super.key, required this.controller});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final TextEditingController _password = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Please enter password to unlock",
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  errorText: error,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final ok = await widget.controller.unlock(_password.text);
                  if (ok) {
                    if (!mounted) return;
                    context.go("/transactions");
                  } else {
                    setState(() => error = "Invalid password");
                  }
                },
                child: const Text("Unlock"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

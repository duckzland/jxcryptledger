import 'package:flutter/material.dart';

class TransactionsPagesSingle extends StatelessWidget {
  final Map<String, dynamic> data;

  const TransactionsPagesSingle({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // final title = "${data['sourceAmount']} ${data['sourceCoin']} → ${data['targetAmount']} ${data['targetCoin']}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Top brief description placeholder
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Transaction Summary Placeholder", style: TextStyle(fontSize: 16)),
        ),

        // Add child transaction button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: () {
              // TODO: implement add child transaction
            },
            child: const Text("Add Child Transaction"),
          ),
        ),

        const SizedBox(height: 20),

        // Child transactions table placeholder
        const Padding(padding: EdgeInsets.all(16.0), child: Text("Child Transactions Table Placeholder")),
      ],
    );
  }
}

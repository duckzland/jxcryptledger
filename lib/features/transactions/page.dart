import 'package:flutter/material.dart';
import '../../app/layout.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Transactions",
      showBack: false,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Filter Placeholder"),
          const SizedBox(height: 20),
          const Text("Transactions Table Placeholder"),
        ],
      ),
    );
  }
}

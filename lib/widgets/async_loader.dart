import 'package:flutter/material.dart';

class WidgetsAsyncLoader extends StatelessWidget {
  final Future<void> future;
  final Widget child;

  const WidgetsAsyncLoader({super.key, required this.future, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return child;
      },
    );
  }
}

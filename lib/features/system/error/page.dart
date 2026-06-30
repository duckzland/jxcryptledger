import 'package:flutter/material.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import 'controller.dart';

class SystemErrorPage extends StatefulWidget {
  final SystemErrorController controller;

  const SystemErrorPage({super.key, required this.controller});

  @override
  State<SystemErrorPage> createState() => _SystemErrorPageState();
}

class _SystemErrorPageState extends State<SystemErrorPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: SizedBox(width: 320, child: _buildErrorUI())),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('v$appVersion', style: const TextStyle(fontSize: 12, color: AppTheme.textInactive)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Column(
      spacing: 20,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const Text(
          "Critical Error",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
        const Text(
          "Oops, something went wrong.\n"
          "The app has paused to keep your data safe.\n\n"
          "Please restart the app.\n"
          "If the problem continues, close any leftover app windows using Task Manager.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
        ),
        // WidgetsButton(
        //   label: "Exit App",
        //   initialState: WidgetsButtonActionState.action,
        //   evaluator: (s) => s.action(),
        //   onPressed: (s) async {
        //     s.progress();
        //     WidgetsBinding.instance.addPostFrameCallback((_) {
        //       // Exit depending on platform
        //       try {
        //         if (Platform.isAndroid) {
        //           SystemNavigator.pop();
        //         } else {
        //           exit(0);
        //         }
        //       } catch (_) {
        //         exit(0);
        //       }
        //     });
        //   },
        // ),
      ],
    );
  }
}

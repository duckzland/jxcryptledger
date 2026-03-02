import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../widgets/panel.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../app/theme.dart';

class ToolsQRGeneratorView extends StatefulWidget {
  const ToolsQRGeneratorView({super.key});

  @override
  State<ToolsQRGeneratorView> createState() => _ToolsQRGeneratorViewState();
}

class _ToolsQRGeneratorViewState extends State<ToolsQRGeneratorView> {
  String? _inputText;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WidgetsFieldsTextarea(
                  title: "Source Text",
                  helperText: "Enter any text to generate the QRCode...",
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 120), () {
                      setState(() {
                        _inputText = value.trim().isEmpty ? null : value.trim();
                      });
                    });
                  },
                ),

                const SizedBox(height: 30),
                Center(child: _buildBarcodeResult()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeResult() {
    if (_inputText == null || _inputText!.isEmpty) {
      return Text(
        "Enter text above to generate the QRCode",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted, letterSpacing: 0.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Generated QRCode",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.separator),
          ),
          child: QrImageView(data: _inputText!, version: QrVersions.auto, size: 240, backgroundColor: Colors.white),
        ),
      ],
    );
  }
}

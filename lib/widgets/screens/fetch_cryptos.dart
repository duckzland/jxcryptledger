import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import '../../core/locator.dart';
import '../../features/cryptos/controller.dart';
import '../button.dart';
import '../notify.dart';

class WidgetsScreensFetchCryptos extends StatefulWidget {
  final String description;

  const WidgetsScreensFetchCryptos({super.key, required this.description});

  @override
  State<WidgetsScreensFetchCryptos> createState() => _WidgetsScreensFetchCryptosState();
}

class _WidgetsScreensFetchCryptosState extends State<WidgetsScreensFetchCryptos> {
  final CryptosController _cryptosController = locator<CryptosController>();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_download_outlined, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Cryptocurrency data not available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: const TextStyle(fontSize: 14, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          WidgetsButton(
            icon: Icons.refresh,
            label: "Download",
            initialState: WidgetsButtonActionState.action,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onPressed: (s) async {
              s.progress();

              try {
                await _cryptosController.fetch();
                widgetsNotifySuccess("Cryptocurrency list successfully retrieved.");
                _cryptosController.getSymbolMap();
                s.action();
                setState(() {});
              } catch (e) {
                if (e is NetworkingException) {
                  widgetsNotifyError(e.userMessage);
                }
              } finally {
                s.reset();
              }
            },
          ),
        ],
      ),
    );
  }
}

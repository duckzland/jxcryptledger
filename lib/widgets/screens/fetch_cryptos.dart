import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/exceptions.dart';
import '../../core/locator.dart';
import '../../features/cryptos/controller.dart';
import '../buttons/action.dart';
import '../notify.dart';

class WidgetsScreensFetchCryptos extends StatefulWidget {
  final String description;

  const WidgetsScreensFetchCryptos({super.key, required this.description});

  @override
  State<WidgetsScreensFetchCryptos> createState() => _WidgetsScreensFetchCryptosState();
}

class _WidgetsScreensFetchCryptosState extends State<WidgetsScreensFetchCryptos> {
  final CryptosController _cryptosController = CoreLocator.getit<CryptosController>();

  void _fetchCryptos(WidgetsButtonsActionState s) async {
    s.progress();

    try {
      await _cryptosController.fetch();
      if (_cryptosController.isNotEmpty()) {
        widgetsNotifySuccess("Cryptocurrency list updated.");
        _cryptosController.generateSymbolMap();

        widgetsNotifyBroadcast("success", "Updated Cryptocurrency list.");
      } else {
        widgetsNotifyError("Failed to retrieve Cryptocurrency list. Please check your internet connection.");
      }
      setState(() {});
    } catch (e) {
      // This is pre IPC. Need new way!.
      if (e is NetworkingException) {
        widgetsNotifyError(e.userMessage);
      }
    } finally {
      s.action();
    }
  }

  void _evaluator(WidgetsButtonsActionState s) async {
    _cryptosController.isFetching ? s.progress() : s.action();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.cloud_download_outlined, size: 60, color: AppTheme.separator),
          SizedBox(height: 16),
          Text('Cryptocurrency data not available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text(
            widget.description,
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ListenableBuilder(
            listenable: _cryptosController,
            builder: (context, _) {
              return WidgetsButtonsAction(
                icon: Icons.refresh,
                iconSize: 16,
                label: "Download",
                initialState: WidgetsButtonActionState.action,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                minimumSize: const Size(40, 40),
                onPressed: _fetchCryptos,
                filledMode: true,
                evaluator: _evaluator,
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/exceptions.dart';
import '../../../../core/locator.dart';
import '../../../../widgets/notify.dart';
import '../../../../widgets/screens/notice.dart';
import '../controller.dart';

class WatchboardsMarketsWidgetsNotice extends StatelessWidget {
  final void Function() callback;
  const WatchboardsMarketsWidgetsNotice({super.key, required this.callback});

  MarketsController get _controller => CoreLocator.getit<MarketsController>();

  @override
  Widget build(BuildContext context) {
    return WidgetsScreensNotice(
      icon: Icons.cloud_download_outlined,
      title: "No market data available",
      btnTitle: "Download",
      btnTooltip: "Retrieve latest market data",
      btnEvaluator: (s) {
        _controller.isFetching ? s.progress() : s.action();
      },
      btnCallback: () async {
        try {
          await _controller.refreshRates();
          if (_controller.isNotEmpty()) {
            widgetsNotifySuccess("Successfully retrieved latest market data.");
          } else {
            widgetsNotifyError("Failed to retrieve market data. Please check your internet connection.");
          }
          callback();
        } catch (e) {
          // This is pre IPC. Need new way!.
          if (e is NetworkingException) {
            widgetsNotifyError(e.userMessage);
          }
        }
      },
    );
  }
}

import 'dart:isolate';

/// Entry point for the isolate.
///
/// This function receives a [SendPort] from the main isolate.
/// It then waits for filter requests and sends results back.
void filterIsolateEntry(SendPort mainSendPort) {
  // Create a port for receiving messages from the main isolate
  final ReceivePort isolateReceivePort = ReceivePort();

  // Send the port back so the main isolate can communicate with us
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((message) async {
    if (message is _FilterRequest) {
      final result = _performFiltering(message.items, message.query);

      // Send the result back
      message.replyPort.send(_FilterResponse(result));
    }
  });
}

/// Actual filtering logic.
///
/// You can replace this with more complex logic later.
List<Map<String, dynamic>> _performFiltering(
  List<Map<String, dynamic>> items,
  String query,
) {
  if (query.trim().isEmpty) return items;

  final lower = query.toLowerCase();

  return items.where((item) {
    return item.values.any(
      (value) => value.toString().toLowerCase().contains(lower),
    );
  }).toList();
}

/// Request model sent to the isolate.
class _FilterRequest {
  final List<Map<String, dynamic>> items;
  final String query;
  final SendPort replyPort;

  _FilterRequest({
    required this.items,
    required this.query,
    required this.replyPort,
  });
}

/// Response model returned from the isolate.
class _FilterResponse {
  final List<Map<String, dynamic>> filteredItems;

  _FilterResponse(this.filteredItems);
}

/// Public API for the main isolate to call filtering.
class FilterIsolate {
  SendPort? _sendPort;

  /// Initializes the isolate if not already running.
  Future<void> init() async {
    if (_sendPort != null) return;

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(filterIsolateEntry, receivePort.sendPort);

    // Wait for the isolate to send back its SendPort
    _sendPort = await receivePort.first as SendPort;
  }

  /// Sends a filter request and waits for the result.
  Future<List<Map<String, dynamic>>> filter(
    List<Map<String, dynamic>> items,
    String query,
  ) async {
    if (_sendPort == null) {
      throw Exception('FilterIsolate not initialized. Call init() first.');
    }

    final ReceivePort responsePort = ReceivePort();

    _sendPort!.send(
      _FilterRequest(
        items: items,
        query: query,
        replyPort: responsePort.sendPort,
      ),
    );

    final response = await responsePort.first as _FilterResponse;
    return response.filteredItems;
  }
}

import 'dart:isolate';

void filterIsolateEntry(SendPort mainSendPort) {

  final ReceivePort isolateReceivePort = ReceivePort();

  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((message) async {
    if (message is _FilterRequest) {
      final result = _performFiltering(message.items, message.query);

      message.replyPort.send(_FilterResponse(result));
    }
  });
}

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

class _FilterResponse {
  final List<Map<String, dynamic>> filteredItems;

  _FilterResponse(this.filteredItems);
}

class FilterIsolate {
  SendPort? _sendPort;

  Future<void> init() async {
    if (_sendPort != null) return;

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(filterIsolateEntry, receivePort.sendPort);

    _sendPort = await receivePort.first as SendPort;
  }

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

class CoreWorkerJob {
  final int id;
  final List<int> payload;
  final Future<void> Function(int, List<int>) callback;
  final bool isFreePlan;

  CoreWorkerJob({required this.id, required this.payload, required this.callback, required this.isFreePlan});
}

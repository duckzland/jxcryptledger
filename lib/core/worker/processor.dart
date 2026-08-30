import 'dart:async';

import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../log.dart';
import 'job.dart';

class CoreWorkerProcessor {
  final Duration watchdogTimeout;
  final int maxWorkers;

  bool isFetching = false;
  Timer? _watchdog;
  Timer? _paused;

  http.Client? _client;
  Completer<void>? _masterAborter;

  bool get isPaused => _paused != null;
  http.Client get client => _client ??= http.Client();

  CoreWorkerProcessor({this.maxWorkers = 5, this.watchdogTimeout = const Duration(seconds: 65)});

  void dispose() {
    _client?.close();
    _watchdog?.cancel();
    _paused?.cancel();

    if (_masterAborter != null && !_masterAborter!.isCompleted) {
      _masterAborter!.completeError(Exception('Processor was disposed.'));
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(watchdogTimeout, () {
      logln("Watchdog triggered — forcing unlock.", "WORKER");
      isFetching = false;

      _client?.close();
      _client = null;

      if (_masterAborter != null && !_masterAborter!.isCompleted) {
        _masterAborter!.completeError(TimeoutException('Watchdog forcefully terminated hanging execution.'));
      }
    });
  }

  void _pauseOperation() {
    logln("Pausing operation.", "WORKER");
    _paused?.cancel();
    _paused = Timer(Duration(seconds: 61), () {
      logln("Resuming operation.", "WORKER");
      _paused?.cancel();
      _paused = null;
    });
  }

  Future<void> run(List<CoreWorkerJob> jobs) async {
    if (jobs.isEmpty) return;

    isFetching = true;

    if (_masterAborter != null && !_masterAborter!.isCompleted) {
      _masterAborter!.completeError(TimeoutException('Terminated by subsequent batch invocation.'));
    }

    _masterAborter = Completer<void>();
    _startWatchdog();

    final iterator = jobs.iterator;
    final hasFreePlanJob = jobs.any((j) => j.isFreePlan);

    int hasFailed = 0;
    int totalWorkers = 5;

    Future<void> worker(int maxWorkers, int workerIndex) async {
      if (workerIndex > 0) {
        await Future.delayed(Duration(milliseconds: workerIndex * (hasFreePlanJob ? 500 : 200)));
      }

      while (hasFailed != 2 && iterator.moveNext()) {
        final job = iterator.current;

        try {
          await job.callback(job.id, job.payload, fetcher: client);
        } catch (e) {
          if (e is NetworkingException && e.details as int == 429) {
            logln("Rate limited, stopping worker: $e", "WORKER");
            hasFailed = 2;
            while (iterator.moveNext()) {}
            break;
          } else {
            hasFailed = 1;
            logln("Unexpected error for job ${job.id}: $e", "WORKER");
          }
        }

        if (hasFailed == 2) break;

        final delayMs = job.isFreePlan ? (60000 / 30 / maxWorkers).ceil() : 300;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (hasFreePlanJob) {
      totalWorkers = jobs.length < totalWorkers ? jobs.length : 1;
    }

    if (totalWorkers > maxWorkers) {
      totalWorkers = maxWorkers;
    }

    final workersToStart = jobs.length == 1 ? 1 : maxWorkers.clamp(1, jobs.length);

    try {
      await Future.any([
        Future.wait(List.generate(workersToStart, (i) => worker(maxWorkers, i)), eagerError: false),
        _masterAborter!.future,
      ]);
    } catch (e) {
      logln("Master thread forcefully detached: $e", "WORKER");
    } finally {
      if (hasFailed == 2) _pauseOperation();
      _watchdog?.cancel();
      _client?.close();
      _client = null;
      isFetching = false;
      if (!_masterAborter!.isCompleted) {
        _masterAborter!.complete();
      }
    }
  }
}

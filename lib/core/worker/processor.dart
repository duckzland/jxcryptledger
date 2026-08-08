import 'dart:async';

import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../log.dart';
import 'job.dart';

class CoreWorkerProcessor {
  bool isFetching = false;
  Timer? _watchdog;
  Timer? _paused;

  http.Client? _client;
  Completer<void>? _masterAborter;

  bool get isPaused => _paused != null;
  http.Client get client => _client ??= http.Client();

  void dispose() {
    _client?.close();
    _watchdog?.cancel();
    _paused?.cancel();

    if (_masterAborter != null && !_masterAborter!.isCompleted) {
      _masterAborter!.completeError(Exception('[WORKER] Processor was disposed.'));
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(Duration(seconds: 65), () {
      logln('[WORKER] Watchdog triggered — forcing unlock.');
      isFetching = false;

      _client?.close();
      _client = null;

      if (_masterAborter != null && !_masterAborter!.isCompleted) {
        _masterAborter!.completeError(TimeoutException('[WORKER] Watchdog forcefully terminated hanging execution.'));
      }
    });
  }

  void _pauseOperation() {
    logln('[WORKER] Pausing operation.');
    _paused?.cancel();
    _paused = Timer(Duration(seconds: 61), () {
      logln('[WORKER] Resuming operation.');
      _paused?.cancel();
      _paused = null;
    });
  }

  Future<void> run(List<CoreWorkerJob> jobs) async {
    if (jobs.isEmpty) return;

    isFetching = true;

    if (_masterAborter != null && !_masterAborter!.isCompleted) {
      _masterAborter!.completeError(TimeoutException('[WORKER] Terminated by subsequent batch invocation.'));
    }

    _masterAborter = Completer<void>();
    _startWatchdog();

    final iterator = jobs.iterator;
    final hasFreePlanJob = jobs.any((j) => j.isFreePlan);

    int hasFailed = 0;
    int maxWorkers = 5;

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
            logln('[WORKER] Rate limited, stopping worker: $e');
            hasFailed = 2;
            while (iterator.moveNext()) {}
            break;
          } else {
            hasFailed = 1;
            logln('[WORKER] Unexpected error for job ${job.id}: $e');
          }
        }

        if (hasFailed == 2) break;

        final delayMs = job.isFreePlan ? (60000 / 30 / maxWorkers).ceil() : 300;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (hasFreePlanJob) {
      maxWorkers = jobs.length < maxWorkers ? jobs.length : 1;
    }

    final workersToStart = jobs.length == 1 ? 1 : maxWorkers.clamp(1, jobs.length);

    try {
      await Future.any([
        Future.wait(List.generate(workersToStart, (i) => worker(maxWorkers, i)), eagerError: false),
        _masterAborter!.future,
      ]);
    } catch (e) {
      logln('[WORKER] Master thread forcefully detached: $e');
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

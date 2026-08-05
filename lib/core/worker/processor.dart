import 'dart:async';

import '../../app/exceptions.dart';
import '../log.dart';
import 'job.dart';

class CoreWorkerProcessor {
  bool isFetching = false;
  Timer? _watchdog;
  Timer? _paused;

  bool get isPaused => _paused != null;

  void dispose() {
    _watchdog?.cancel();
    _paused?.cancel();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 65), () {
      logln('[WORKER] Watchdog triggered — forcing unlock.');
      isFetching = false;
    });
  }

  void _pauseOperation() {
    logln('[WORKER] Pausing operation.');
    _paused?.cancel();
    _paused = Timer(const Duration(seconds: 61), () {
      logln('[WORKER] Resuming operation.');
      _paused?.cancel();
      _paused = null;
    });
  }

  Future<void> run(List<CoreWorkerJob> jobs) async {
    if (jobs.isEmpty) return;

    isFetching = true;
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
          await job.callback(job.id, job.payload);
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

    await Future.wait(List.generate(workersToStart, (i) => worker(maxWorkers, i)), eagerError: false);

    if (hasFailed == 2) _pauseOperation();

    _watchdog?.cancel();
    isFetching = false;
  }
}

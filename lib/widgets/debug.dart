import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/locator.dart';
import '../core/log.dart';
import '../ipc/client.dart';
import '../ipc/status/op.dart';

class WidgetsDebug extends StatefulWidget {
  const WidgetsDebug({super.key});

  @override
  State<WidgetsDebug> createState() => _WidgetsDebugState();
}

class _WidgetsDebugState extends State<WidgetsDebug> {
  Timer? _timer;
  String _cpu = '--';
  String _memory = '--';
  double? _previousCpuSeconds;
  DateTime? _previousCpuSample;

  @override
  void initState() {
    super.initState();
    _updateMetrics();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateMetrics());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _reloadServer();
  }

  Future<void> _reloadServer() async {
    try {
      final ipcClient = CoreLocator.getit<IpcClient>();
      await ipcClient.send(op: IpcStatusOp.getCode('reload'), action: 'reload');
    } catch (error) {
      logln('Failed to reload server: $error', 'APP');
    }
  }

  Future<void> _updateMetrics() async {
    final memory = ProcessInfo.currentRss / (1024 * 1024);
    final cpu = await _readCpuUsage();

    if (!mounted) return;
    setState(() {
      _memory = '${memory.toStringAsFixed(1)} MB';
      if (cpu != null) _cpu = '${cpu.toStringAsFixed(1)}%';
    });
  }

  Future<double?> _readCpuUsage() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', ['-NoProfile', '-Command', '(Get-Process -Id $pid).CPU']);
        final cpuSeconds = double.tryParse(result.stdout.toString().trim());
        if (cpuSeconds == null) return null;

        final now = DateTime.now();
        final previousSeconds = _previousCpuSeconds;
        final previousSample = _previousCpuSample;
        _previousCpuSeconds = cpuSeconds;
        _previousCpuSample = now;
        if (previousSeconds == null || previousSample == null) return null;

        final elapsedSeconds = now.difference(previousSample).inMicroseconds / 1000000;
        if (elapsedSeconds <= 0) return null;
        return ((cpuSeconds - previousSeconds) / elapsedSeconds / Platform.numberOfProcessors * 100).clamp(0, 100);
      }

      final result = await Process.run('ps', ['-p', '$pid', '-o', '%cpu=']);
      return double.tryParse(utf8.decode(result.stdout is List<int> ? result.stdout : utf8.encode(result.stdout.toString())).trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8, left: 12, right: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            child: Row(spacing: 10, mainAxisSize: MainAxisSize.min, children: [Text('CPU $_cpu'), Text('MEM $_memory')]),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:jxledger/core/log.dart';

void main() async {
  final rcFile = File('windows/runner/Runner.rc');

  const String rcPath = r'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\rc.exe';
  const String sdkIncludeShared = r'C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared';
  const String sdkIncludeUm = r'C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um';

  if (!await rcFile.exists()) {
    logln("Error: Runner.rc file not found at expected location.");
    exit(1);
  }

  if (!File(rcPath).existsSync()) {
    logln("Error: Hardcoded compiler path is invalid or missing: $rcPath");
    exit(1);
  }

  logln("Testing icon compliance via local compiler with SDK headers...");
  logln("Compiler: $rcPath\n");

  // We turn off runInShell so the operating system handles the spaces perfectly
  final result = Process.runSync(
    rcPath,
    ['/v', '/fo', 'test_output.res', '/i', sdkIncludeShared, '/i', sdkIncludeUm, 'Runner.rc'],
    workingDirectory: 'windows/runner',
    runInShell: false, // 👈 CRITICAL: Set to false to bypass the cmd.exe quoting bug
  );

  // Quick cleanup of test compilation artifacts
  final dummyResFile = File('windows/runner/test_output.res');
  if (await dummyResFile.exists()) {
    await dummyResFile.delete();
  }

  final outputLog = result.stdout.toString() + result.stderr.toString();

  if (result.exitCode == 0 && !outputLog.contains('RC2176')) {
    logln("VERIFICATION PASSED!");
    exit(0);
  } else {
    logln("COMPILER TEST FAILED!");
    logln("===================== ERROR LOGS =====================");
    logln(outputLog.trim());
    logln("======================================================");
    exit(1);
  }
}

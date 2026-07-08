import 'dart:io';

void main() async {
  final rcFile = File('windows/runner/Runner.rc');

  const String rcPath = r'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\rc.exe';
  const String sdkIncludeShared = r'C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared';
  const String sdkIncludeUm = r'C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um';

  if (!await rcFile.exists()) {
    print("Error: Runner.rc file not found at expected location.");
    exit(1);
  }

  if (!File(rcPath).existsSync()) {
    print("Error: Hardcoded compiler path is invalid or missing: $rcPath");
    exit(1);
  }

  print("Testing icon compliance via local compiler with SDK headers...");
  print("Compiler: $rcPath\n");

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
    print("VERIFICATION PASSED!");
    exit(0);
  } else {
    print("COMPILER TEST FAILED!");
    print("===================== ERROR LOGS =====================");
    print(outputLog.trim());
    print("======================================================");
    exit(1);
  }
}

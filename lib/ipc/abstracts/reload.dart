import 'dart:io';
import 'dart:developer' as developer;
import 'package:vm_service/vm_service_io.dart';

abstract class IpcReload {
  String get directory => '.dart_tool/flutter_build';
  String get incrementalFileName => 'main.dart.incremental.dill';
  String get fullkernelFileName => 'app.dill';

  Future<void> run() async {
    final buildDirectory = Directory(directory);
    final projectName = Directory.current.path.split(Platform.pathSeparator).last.toLowerCase();

    final incrementalFiles = await Directory.systemTemp
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.toLowerCase().contains(projectName) && entity.path.endsWith(incrementalFileName))
        .cast<File>()
        .toList();

    final fullKernelFiles = await buildDirectory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith(fullkernelFileName))
        .cast<File>()
        .toList();

    final dillFiles = incrementalFiles.isNotEmpty ? incrementalFiles : fullKernelFiles;

    if (dillFiles.isEmpty) {
      throw StateError('No generated Flutter kernel found');
    }

    dillFiles.sort((left, right) => right.lastModifiedSync().compareTo(left.lastModifiedSync()));

    final absoluteDillPath = dillFiles.first.absolute.path;

    final sourceFiles = await Directory(
      'lib',
    ).list(recursive: true).where((entity) => entity is File && entity.path.endsWith('.dart')).cast<File>().toList();

    final latestSourceTime = sourceFiles.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : sourceFiles.map((file) => file.lastModifiedSync()).reduce((left, right) => left.isAfter(right) ? left : right);

    final kernelTime = dillFiles.first.lastModifiedSync();

    if (kernelTime.isBefore(latestSourceTime)) {
      throw StateError('Selected kernel is stale: kernel=$kernelTime source=$latestSourceTime');
    }

    final serviceInfo = await developer.Service.getInfo();
    final serviceUri = serviceInfo.serverUri;

    if (serviceUri == null) {
      throw StateError('VM service is unavailable; start the process with --enable-vm-service');
    }

    final wsPath = serviceUri.path.endsWith('/') ? '${serviceUri.path}ws' : '${serviceUri.path}/ws';
    final wsUri = serviceUri.replace(scheme: serviceUri.scheme == 'https' ? 'wss' : 'ws', path: wsPath).toString();

    final vmService = await vmServiceConnectUri(wsUri);
    final vm = await vmService.getVM();
    final mainIsolateId = vm.isolates!.first.id!;

    final reloadReport = await vmService.reloadSources(mainIsolateId, rootLibUri: Uri.file(absoluteDillPath).toString());

    if (reloadReport.success != true) {
      final errorDetails = reloadReport.json?['notices'] ?? reloadReport.json;
      throw StateError('Reload failed. Details: $errorDetails');
    }

    await vmService.dispose();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:sentinel/project.dart';

import 'test_file_match.dart';

// ignore_for_file: avoid_print

abstract class TestRunner {
  Future<bool> run({
    TestFileMatch? match,
    bool noIntegration = false,
    String device = 'all',
  });

  bool get running;
  Future<bool> terminate();
  Future<bool> kill();

  factory TestRunner(Project project) => _TestRunner(project);
}

class _TestRunner implements TestRunner {
  final Project project;
  Process? process;
  bool? _isFlutterProject;
  Future<void>? _running;

  _TestRunner(this.project);

  Future<bool> get isFlutterProject async {
    _isFlutterProject ??= await project.isFlutter();
    return _isFlutterProject!;
  }

  @override
  bool get running => _running != null;
  int? get pid => process?.pid;

  Future<List<FileSystemEntity>> _getIntegrationTestFiles() {
    final dir = Directory(p.join(project.rootPath, 'integration_test'));
    final files = <FileSystemEntity>[];
    final completer = Completer<List<FileSystemEntity>>();
    final lister = dir.list(recursive: true);
    lister.listen(
      (file) {
        if (file.path.endsWith('_test.dart')) {
          files.add(file);
        }
      },
      onDone: () => completer.complete(files),
    );
    return completer.future;
  }

  Future<bool> _runIntegrationTest(String path, {String device = 'all'}) async {
    final args = ['drive', '--driver=integration_test/driver.dart'];
    if (device != 'all') {
      args.add('-d');
      args.add(device);
    }
    if (path != '') {
      final relativePath = path.replaceFirst(project.rootPath, '');
      print('\nRunning single integration test for $relativePath');
      args.add('--target=$path');
      return _execute(args);
    }
    print('\nRunning all integration tests');
    final integrationTestFiles = await _getIntegrationTestFiles();
    if (integrationTestFiles.isEmpty) {
      print('\nNo integration test files found.');
      return true;
    }
    for (final file in integrationTestFiles) {
      final result = await _runIntegrationTest(file.path, device: device);
      if (!result) {
        return result;
      }
    }
    return true;
  }

  Future<bool> _runBasicTest([String path = '']) async {
    final args = ['test'];
    if (await isFlutterProject) {
      args.add('--no-pub');
      args.add('--suppress-analytics');
    }
    if (path != '') {
      final relativePath = path.replaceFirst(project.rootPath, '');
      print('\nRunning single unit test for $relativePath');
      args.add(path);
    } else {
      print('\nRunning all unit tests');
    }

    return _execute(args);
  }

  Future<String> _mainCommand() async {
    return await isFlutterProject ? 'flutter' : 'dart';
  }

  Future<bool> _execute(List<String> args) async {
    var success = false;
    try {
      const mode = ProcessStartMode.inheritStdio;
      // const mode = ProcessStartMode.normal;
      // const mode = ProcessStartMode.detachedWithStdio;
      process = await Process.start(
        await _mainCommand(),
        args,
        workingDirectory: project.rootPath,
        mode: mode,
      );
      if (process is Process) {
        final proc = process!;
        final ioWait = mode == ProcessStartMode.normal
            ? Future.wait([
                proc.stdout.pipe(stdout),
                proc.stderr.pipe(stdout),
              ])
            : Future.value(true);
        final exitCode = await proc.exitCode;
        await ioWait;
        if (exitCode != 0) {
          if (exitCode == -9 || exitCode == -15) {
            // -9 is SIGKILL - we probably killed it ourselves
            // -15 is SIGTERM - we probably terminated it ourselves
            success = true;
          } else {
            print('Run exited with exit code: $exitCode');
            success = false;
          }
        } else {
          success = true;
        }
      }
    } catch (e, stacktrace) {
      print(e);
      print(stacktrace);
      success = false;
    }
    process = null;
    return success;
  }

  @override
  Future<bool> run({
    TestFileMatch? match,
    bool noIntegration = false,
    String device = 'all',
  }) async {
    if (_running != null) {
      await _running;
      return true;
    }

    final completer = Completer<void>();
    _running = completer.future;

    var success = false;
    if (match == null) {
      // Run all tests
      success = await _runBasicTest() &&
          (noIntegration ||
              await _runIntegrationTest(
                '',
                device: device,
              ));
    } else {
      success = match.integrationTest
          ? (noIntegration ||
              await _runIntegrationTest(
                match.path,
                device: device,
              ))
          : await _runBasicTest(match.path);
    }

    completer.complete();
    _running = null;
    return success;
  }

  @override
  Future<bool> terminate() async {
    if (process is Process) {
      final proc = process!;
      // SIGTERM - needs to be called twice. Use SIGKILL if SIGTERM is not necessary
      proc.kill();
      await Future.delayed(const Duration(milliseconds: 60));
      final result = proc.kill();

      if (_running is Future<void>) {
        await _running;
      }
      return result;
    }
    return false;
  }

  @override
  Future<bool> kill() async {
    if (process is Process) {
      final result = process!.kill(ProcessSignal.sigkill);
      if (_running is Future<void>) {
        await _running;
      }
      return result;
    }
    return false;
  }
}

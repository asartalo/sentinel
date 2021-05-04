import 'dart:async';
import 'dart:io';

import 'package:sentinel/project.dart';

import 'test_file_match.dart';

// ignore_for_file: avoid_print
class TestRunner {
  final Project project;
  Process? process;
  bool? _isFlutterProject;
  Future<void>? _running;

  TestRunner(this.project);

  Future<bool> get isFlutterProject async {
    _isFlutterProject ??= await project.isFlutter();
    return _isFlutterProject!;
  }

  bool get running => _running != null;
  int? get pid => process?.pid;

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
    } else {
      print('\nRunning all integration tests');
      args.add('integration_test/all_tests.dart');
    }

    return _execute(args);
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
      final mode = ProcessStartMode.inheritStdio;
      // final mode = ProcessStartMode.normal;
      // final mode = ProcessStartMode.detachedWithStdio;
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

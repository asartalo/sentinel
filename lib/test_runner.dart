import 'dart:async';
import 'dart:io';

import 'package:sentinel/test_file_match.dart';

class TestRunner {
  final String workingDir;
  late Process? process;
  Future<Null>? _running;

  TestRunner(this.workingDir);

  bool get running => _running != null;

  Future<bool> _runIntegrationTest(String path, {String device = 'all'}) async {
    final args = ['drive', '--driver=integration_test/driver.dart'];
    if (device != 'all') {
      args.add('-d');
      args.add(device);
    }
    if (path != '') {
      final relativePath = path.replaceFirst(workingDir, '');
      print('Running single integration test for $relativePath');
      args.add('--target=$path');
    } else {
      print('Running all integration tests');
      args.add('integration_test/all_tests.dart');
    }

    return _execute(args);
  }

  Future<bool> _runBasicTest([String path = '']) async {
    final args = ['test', '--no-pub', '--suppress-analytics'];
    if (path != '') {
      final relativePath = path.replaceFirst(workingDir, '');
      print('Running single unit test for $relativePath');
      args.add(path);
    } else {
      print('Running all unit tests');
    }

    return _execute(args);
  }

  Future<bool> _execute(List<String> args) async {
    var success = false;
    try {
      process = await Process.start(
        'flutter',
        args,
        workingDirectory: workingDir,
        mode: ProcessStartMode.inheritStdio,
      );
      final exitCode = await process!.exitCode;
      if (exitCode != 0) {
        print('Test exited with exit code: $exitCode');
        success = false;
      } else {
        success = true;
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
    noIntegration = false,
    String device = 'all',
  }) async {
    if (_running != null) {
      await _running;
      return true;
    }

    final completer = Completer<Null>();
    _running = completer.future;

    var success = false;
    if (match == null) {
      // Run all tests
      success = await _runBasicTest() &&
          (noIntegration
              ? true
              : await _runIntegrationTest(
                  '',
                  device: device,
                ));
    } else {
      success = match.integrationTest
          ? (noIntegration
              ? true
              : await _runIntegrationTest(
                  match.path,
                  device: device,
                ))
          : await _runBasicTest(match.path);
    }

    completer.complete();
    _running = null;
    return success;
  }

  bool kill() {
    if (process is Process) {
      return process!.kill(ProcessSignal.sigkill);
    }
    return false;
  }
}

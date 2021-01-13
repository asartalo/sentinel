import 'dart:async';
import 'dart:io';

import 'package:io/io.dart';
import 'package:sentinel/test_file_match.dart';

class TestRunner {
  final String workingDir;
  Process process;
  Future<Null> _running;
  final _manager = ProcessManager();

  TestRunner(this.workingDir);

  bool get running => _running != null;

  Future<bool> _runIntegrationTest([String path = '']) async {
    final args = ['drive', '--driver=integration_test/driver.dart'];
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

  Future<bool> _execute(args) async {
    var success = false;
    try {
      process = await _manager.spawn(
        'flutter',
        args,
        workingDirectory: workingDir,
      );
      final exitCode = await process.exitCode;
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

  Future<bool> run({TestFileMatch match, noIntegration = false}) async {
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
          (noIntegration ? true : await _runIntegrationTest());
    } else {
      success = match.integrationTest
          ? (noIntegration ? true : await _runIntegrationTest(match.path))
          : await _runBasicTest(match.path);
    }

    completer.complete();
    _running = null;
    return success;
  }

  bool kill() {
    if (process == null) {
      return false;
    }
    return process.kill(ProcessSignal.sigkill);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:io/io.dart';

class TestRunner {
  final String workingDir;
  Process process;
  Future<Null> _running;
  final _manager = ProcessManager();

  TestRunner(this.workingDir);

  bool get running => _running != null;

  Future<bool> run([String path = '']) async {
    if (_running != null) {
      await _running;
      return true;
    }

    // Run all tests
    final completer = Completer<Null>();
    _running = completer.future;
    var args = ['test', '--no-pub', '--suppress-analytics'];
    if (path != '') {
      var relativePath = path.replaceFirst(workingDir, '');
      print('Running single test for $relativePath');
      args.add(path);
    } else {
      print('Running all tests');
    }

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
    } catch (e) {
      print(e);
      success = false;
    }
    completer.complete();
    _running = null;
    process = null;
    return success;
  }

  bool kill() {
    if (process == null) {
      return false;
    }
    return process.kill(ProcessSignal.sigkill);
  }
}

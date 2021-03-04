import 'dart:async';
import 'dart:io';

import 'package:sentinel/project.dart';

// ignore_for_file: avoid_print
class TestRunner {
  final Project project;
  late Process? process;
  bool? _isFlutterProject;
  Future<void>? _running;

  TestRunner(this.project);

  Future<bool> get isFlutterProject async {
    _isFlutterProject ??= await project.isFlutter();
    return _isFlutterProject!;
  }

  bool get running => _running != null;

  Future<bool> _runIntegrationTest(String path, {String device = 'all'}) async {
    final args = ['drive', '--driver=integration_test/driver.dart'];
    if (device != 'all') {
      args.add('-d');
      args.add(device);
    }
    if (path != '') {
      final relativePath = path.replaceFirst(project.rootPath, '');
      print('Running single integration test for $relativePath');
      args.add('--target=$path');
    } else {
      print('Running all integration tests');
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
      print('Running single unit test for $relativePath');
      args.add(path);
    } else {
      print('Running all unit tests');
    }

    return _execute(args);
  }

  Future<String> _mainCommand() async {
    return await isFlutterProject ? 'flutter' : 'dart';
  }

  Future<bool> _execute(List<String> args) async {
    var success = false;
    try {
      process = await Process.start(
        await _mainCommand(),
        args,
        workingDirectory: project.rootPath,
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

  bool kill() {
    if (process is Process) {
      return process!.kill(ProcessSignal.sigkill);
    }
    return false;
  }
}

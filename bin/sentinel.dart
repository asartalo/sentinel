import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:sentinel/path_tests.dart';
import 'package:sentinel/test_file_match.dart';
import 'package:sentinel/test_runner.dart';
import 'package:watcher/watcher.dart';

void main(List<String> arguments) async {
  exitCode = 0;

  stdout.encoding = SystemEncoding();

  try {
    final parser = ArgParser();
    final pathArgs = parser.parse(arguments).rest;
    final fullPath = await getPathFromArgsOrCurrent(pathArgs);

    watchDirectory(fullPath);
  } catch (e) {
    exitCode = 1;
    stderr.writeln(e.toString());
    return;
  }
}

void watchDirectory(String rootPath) {
  print('Watching "${p.relative(rootPath)}" ...');

  final watcher = DirectoryWatcher(rootPath);
  final testRunner = TestRunner(rootPath);
  var canSkip = true;
  Timer timer;
  // var clearer = ProcessManager();

  watcher.events.listen((event) async {
    if (!canSkip || isIgnore(event.path, rootPath) || isFunnyFile(event.path)) {
      return;
    }

    // Clear the screen before running tests
    print('\x1B[2J');

    if (canSkip && testRunner.running) {
      testRunner.kill();
      if (timer != null) {
        timer.cancel();
      }
    }

    canSkip = false;
    timer = Timer(Duration(seconds: 1), () {
      canSkip = true;
    });

    print('TEST RUN: ${event.type} ${event.path}\n');

    var continueAllTests = true;

    final testFileMatch = findMatchingTest(event.path, rootPath);
    if (testFileMatch.exists) {
      continueAllTests = await testRunner.run(testFileMatch.path);
    }

    if (continueAllTests) {
      await testRunner.run();
    }
    canSkip = true;
    timer.cancel();
  });
}

Future<String> getPathFromArgsOrCurrent(List<String> args) async {
  if (args.isNotEmpty) {
    var dir = args.first;
    if (!(await FileSystemEntity.isDirectory(dir))) {
      throw Exception('Error: Path "$dir" is not a directory');
    }

    return p.canonicalize(dir);
  }
  return p.canonicalize(Directory.current.path);
}

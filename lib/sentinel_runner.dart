import 'dart:async';

import 'package:args/args.dart';
import 'package:sentinel/aitf_builder.dart';
import 'package:sentinel/test_runner.dart';
import 'package:watcher/watcher.dart';

import 'path_tests.dart';
import 'printer.dart';
import 'project.dart';

typedef AllTestsBuilder = Future<void> Function(Project project);

class SentinelRunner {
  final Printer printer;
  final String sep;
  final Project project;
  final AllTestsBuilder allTestsBuilder;

  SentinelRunner(
      {required this.printer,
      required this.project,
      this.sep = '/',
      this.allTestsBuilder = aitfBuilder});

  Function(WatchEvent) createListener({
    required TestRunner testRunner,
    required bool isFlutter,
    String device = 'all',
    bool noIntegration = false,
  }) {
    Timer? timer;

    bool canSkip = true;
    bool debounce = false;

    return (WatchEvent event) async {
      if (debounce) {
        return;
      }
      if (!canSkip || isIgnore(event.path, project)) {
        return;
      }

      debounce = true;
      Timer(const Duration(milliseconds: 300), () {
        debounce = false;
      });

      // Clear the screen before running tests
      printer.println('\x1B[2J');

      canSkip = false;
      timer = Timer(const Duration(seconds: 3), () {
        canSkip = true;
      });

      if (canSkip && testRunner.running) {
        await testRunner.terminate();
        if (timer is Timer) {
          timer!.cancel();
        }
      }

      printer.println('TEST RUN: ${event.type} ${event.path}\n');

      var continueAllTests = true;

      // Skip to running all tests file is removed
      if (event.type != ChangeType.REMOVE) {
        final testFileMatch = await project.findMatchingTest(event.path);
        if (testFileMatch.integrationTest) {
          await prepareAllIntegrationTests(project);
        }

        if (testFileMatch.exists) {
          continueAllTests = await testRunner.run(
            match: testFileMatch,
            noIntegration: noIntegration,
            device: device,
          );
        }
      }

      if (continueAllTests) {
        await testRunner.run(
          noIntegration: noIntegration,
          device: device,
        );
      }
      canSkip = true;
      debounce = false;
      if (timer is Timer) {
        timer!.cancel();
      }
    };
  }

  Future<void> watchDirectory({
    bool noIntegration = false,
    String device = 'all',
  }) async {
    printer.println('Watching "${project.rootPath}" ...');

    final isFlutter = await project.isFlutter();

    final noIntegrations =
        noIntegration || !await project.hasIntegrationTestDir();

    if (isFlutter) {
      printer.println('Looks like a flutter project');
    } else {
      printer.println('Looks like a regular Dart project');
    }

    if (noIntegration) {
      printer.println('Skipping integration tests');
    }

    final testRunner = TestRunner(project);

    final listener = createListener(
      testRunner: testRunner,
      isFlutter: isFlutter,
      noIntegration: noIntegration,
      device: device,
    );

    final directories = [
      'lib',
      'data',
      'fonts',
      'test',
      'integration_test',
    ];

    for (final folder in directories) {
      final dir = project.getDir(folder);
      if (await dir.exists()) {
        final watcher = DirectoryWatcher(dir.path);
        watcher.events.listen(listener);
      }
    }
  }

  Future<void> prepareAllIntegrationTests(Project project) async {
    await allTestsBuilder(project);
  }

  void printHelp(ArgParser parser) {
    printer.println('''
  A Dart and Flutter project automated test runner.

  Usage: sentinel [<flags>] <directory>

  ${parser.usage}

  See https://pub.dev/packages/sentinel for more information.''');
  }
}

import 'dart:async';

import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:sentinel/test_runner.dart';
import 'package:watcher/watcher.dart';

import 'path_tests.dart';
import 'printer.dart';
import 'project.dart';

const allTestsFileTemplate = '''
  // IMPORTS

  ''';

class SentinelRunner {
  final Printer printer;
  final FileSystem fs;
  final String sep;

  SentinelRunner({required this.printer, required this.fs, this.sep = '/'});

  Future<Function(WatchEvent)> createListener(
    Project project, {
    bool noIntegration = false,
    String device = 'all',
  }) async {
    final isFlutter = await project.isFlutter();
    final testRunner = TestRunner(project);
    final noIntegrations =
        noIntegration || !await project.hasIntegrationTestDir();
    bool canSkip = true;
    bool debounce = false;
    late Timer timer;

    if (isFlutter) {
      printer.println('Looks like a flutter project');
    } else {
      printer.println('Looks like a regular Dart project');
    }

    if (noIntegration) {
      printer.println('Skipping integration tests');
    }

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

      if (canSkip && testRunner.running) {
        await testRunner.terminate();
        timer.cancel();
      }

      canSkip = false;
      timer = Timer(const Duration(seconds: 3), () {
        canSkip = true;
      });

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
          noIntegration: noIntegrations,
          device: device,
        );
      }
      canSkip = true;
      debounce = false;
      timer.cancel();
    };
  }

  Future<void> watchDirectory(
    String rootPath, {
    bool noIntegration = false,
    String device = 'all',
  }) async {
    printer.println('Watching "$rootPath" ...');

    final project = Project(rootPath, fs);
    final listener = await createListener(
      project,
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
      final fullPath = fs.path.join(rootPath, folder);
      if (await fs.directory(fullPath).exists()) {
        final watcher = DirectoryWatcher(fullPath);
        watcher.events.listen(listener);
      }
    }
  }

  Future<void> prepareAllIntegrationTests(Project project) async {
    await writeAllTestsFile(
      fs.file(fs.path.join(project.integrationTestDirPath, 'all_tests.dart')),
      project,
    );
  }

  Future<void> writeAllTestsFile(
    File allTestsFile,
    Project project,
  ) async {
    final testFiles = await project.getIntegrationTestFiles();
    final testDir = project.integrationTestDirPath;
    final imports = [
      "import 'package:integration_test/integration_test.dart';"
    ];
    final invokables = [];
    for (final testFile in testFiles) {
      var relativePath = fs.path.relative(testFile.path, from: testDir);
      if (sep != '/') {
        relativePath = relativePath.replaceAll(sep, '/');
      }
      final invokable = invokableFromPath(relativePath);
      imports.add("import './$relativePath' as $invokable;");
      invokables.add('await $invokable.main();');
    }
    await allTestsFile.writeAsString('''
  ${imports.join('\n')}

  Future<void> main() async {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    ${invokables.join('\n  ')}
  }
  ''');
  }

  String invokableFromPath(String path) {
    return path.replaceAll('/', '_').replaceAll(RegExp(r'\.dart$'), '');
  }

  void printHelp(ArgParser parser) {
    printer.println('''
  A Dart and Flutter project automated test runner.

  Usage: sentinel [<flags>] <directory>

  ${parser.usage}

  See https://pub.dev/packages/sentinel for more information.''');
  }
}

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:file/local.dart';
import 'package:sentinel/path_tests.dart';
import 'package:sentinel/project.dart';
import 'package:sentinel/test_runner.dart';
import 'package:watcher/watcher.dart';

const fs = LocalFileSystem();

// ignore_for_file: avoid_print
Future<void> main(List<String> arguments) async {
  exitCode = 0;

  stdout.encoding = const SystemEncoding();

  try {
    final parser = ArgParser();
    parser.addFlag(
      'integration',
      negatable: false,
      abbr: 'i',
    );
    parser.addOption('device', abbr: 'd', defaultsTo: 'all');
    final args = parser.parse(arguments);
    final pathArgs = args.rest;
    final fullPath = await getPathFromArgsOrCurrent(pathArgs);

    final noIntegration = !(args['integration'] as bool);

    await watchDirectory(
      fullPath,
      noIntegration: noIntegration,
      device: args['device'] as String,
    );
  } catch (e) {
    exitCode = 1;
    stderr.writeln(e.toString());
    return;
  }
}

Future<Function(WatchEvent)> createListener(
  Project project, {
  bool noIntegration = false,
  String device = 'all',
}) async {
  final isFlutter = await project.isFlutter();
  final testRunner = TestRunner(project);
  final noIntegrations =
      noIntegration || !await project.hasIntegrationTestDir();
  var canSkip = true;
  late Timer timer;

  if (isFlutter) {
    print('Looks like a flutter project');
  } else {
    print('Looks like a regular Dart project');
  }

  if (noIntegration) {
    print('Skipping integration tests');
  }

  return (WatchEvent event) async {
    if (!canSkip || isIgnore(event.path, project)) {
      return;
    }

    // Clear the screen before running tests
    print('\x1B[2J');

    if (canSkip && testRunner.running) {
      testRunner.kill();
      timer.cancel();
    }

    canSkip = false;
    timer = Timer(const Duration(seconds: 3), () {
      canSkip = true;
    });

    print('TEST RUN: ${event.type} ${event.path}\n');

    var continueAllTests = true;

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

    if (continueAllTests) {
      await testRunner.run(
        noIntegration: noIntegrations,
        device: device,
      );
    }
    canSkip = true;
    timer.cancel();
  };
}

Future<void> watchDirectory(
  String rootPath, {
  bool noIntegration = false,
  String device = 'all',
}) async {
  print('Watching "$rootPath" ...');

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
    if (await Directory(fullPath).exists()) {
      final watcher = DirectoryWatcher(fullPath);
      watcher.events.listen(listener);
    }
  }
}

Future<void> prepareAllIntegrationTests(Project project) async {
  await writeAllTestsFile(
    File(fs.path.join(project.integrationTesDirPath, 'all_tests.dart')),
    project,
  );
}

const allTestsFileTemplatea = '''
// IMPORTS

''';

final sep = Platform.pathSeparator;

Future<void> writeAllTestsFile(
  File allTestsFile,
  Project project,
) async {
  final testFiles = await project.getIntegrationTestFiles();
  final testDir = project.integrationTesDirPath;
  final imports = ["import 'package:integration_test/integration_test.dart';"];
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

Future<String> getPathFromArgsOrCurrent(List<String> args) async {
  if (args.isNotEmpty) {
    final dir = args.first;
    if (!(await FileSystemEntity.isDirectory(dir))) {
      throw Exception('Error: Path "$dir" is not a directory');
    }

    return fs.path.canonicalize(dir);
  }
  return fs.path.canonicalize(Directory.current.path);
}

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
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
    parser.addFlag('no-integration', negatable: false, abbr: 'I');
    parser.addOption('device', abbr: 'd', defaultsTo: 'all');
    final args = parser.parse(arguments);
    final pathArgs = args.rest;
    final fullPath = await getPathFromArgsOrCurrent(pathArgs);

    final noIntegration = args['no-integration'] ||
        !(await hasIntegrationTestDirectory(fullPath));

    await watchDirectory(
      fullPath,
      noIntegration: noIntegration,
      device: args['device'],
    );
  } catch (e) {
    exitCode = 1;
    stderr.writeln(e.toString());
    return;
  }
}

Future<bool> hasIntegrationTestDirectory(String rootPath) {
  return Directory(p.join(rootPath, 'integration_test')).exists();
}

bool isFlutterProject(String rootPath) {
  final file = File(p.join(rootPath, 'pubspec.yaml'));
  final fileContents = file.readAsStringSync();
  return fileContents.contains('\nflutter:');
}

Function(WatchEvent) createListener(
  rootPath, {
  noIntegration = false,
  device = 'all',
}) {
  final isFlutter = isFlutterProject(rootPath);
  final testRunner = TestRunner(rootPath, isFlutterProject: isFlutter);
  var canSkip = true;
  late Timer timer;

  if (isFlutter) {
    print('Looks like a flutter project');
  } else {
    print('Looks like a regular dart project');
  }

  if (noIntegration) {
    print('Skipping integration tests');
  }

  return (event) async {
    if (!canSkip || isIgnore(event.path, rootPath)) {
      return;
    }

    // Clear the screen before running tests
    print('\x1B[2J');

    if (canSkip && testRunner.running) {
      testRunner.kill();
      timer.cancel();
    }

    canSkip = false;
    timer = Timer(Duration(seconds: 3), () {
      canSkip = true;
    });

    print('TEST RUN: ${event.type} ${event.path}\n');

    var continueAllTests = true;

    final testFileMatch = findMatchingTest(event.path, rootPath);
    if (testFileMatch.integrationTest) {
      await prepareAllIntegrationTests(rootPath);
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
        noIntegration: noIntegration,
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
  print('Watching "${p.relative(rootPath)}" ...');

  final listener = createListener(
    rootPath,
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
    final fullPath = p.join(rootPath, folder);
    if (await Directory(fullPath).exists()) {
      final watcher = DirectoryWatcher(fullPath);
      watcher.events.listen(listener);
    }
  }
}

Future<void> prepareAllIntegrationTests(String rootPath) async {
  // allTestsFile.openWrite();
  final testFiles = await getTestFiles(rootPath);

  await writeAllTestsFile(
    File(p.join(rootPath, 'integration_test', 'all_tests.dart')),
    rootPath,
    testFiles,
  );
  // write all_tests.dart
}

const allTestsFileTemplatea = '''
// IMPORTS

''';

final sep = Platform.pathSeparator;

Future<void> writeAllTestsFile(
  File allTestsFile,
  String rootPath,
  List<File> testFiles,
) async {
  final testDir = p.join(rootPath, 'integration_test');
  final imports = ["import 'package:integration_test/integration_test.dart';"];
  final invokables = [];
  for (final testFile in testFiles) {
    var relativePath = p.relative(testFile.path, from: testDir);
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

Future<List<File>> getTestFiles(rootPath) {
  final dir = Directory(p.join(rootPath, 'integration_test'));
  final files = <File>[];
  final completer = Completer<List<File>>();
  final lister = dir.list(recursive: true);
  lister.listen(
    (file) {
      if (file is File && file.path.endsWith('_test.dart')) {
        files.add(file);
      }
    },
    onDone: () => completer.complete(files),
  );
  return completer.future;
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

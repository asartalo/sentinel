import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentinel/printer.dart';
import 'package:sentinel/project.dart';
import 'package:sentinel/sentinel_runner.dart';
import 'package:sentinel/test_file_match.dart';
import 'package:sentinel/test_runner.dart';
import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

import 'helpers.dart';

void main() {
  group(SentinelRunner, () {
    late SentinelRunner runner;
    late StubPrinter printer;
    late FileSystem fs;
    late String rootDir;
    late Project project;
    late FileHelpers helper;

    Future<void> stubAllTestsBuilder(Project project) async {}

    setUp(() {
      printer = StubPrinter();
      fs = MemoryFileSystem();
      rootDir = fs.systemTempDirectory.path;
      helper = FileHelpers(fs, rootDir);
      project = Project(rootDir, fs);
      runner = SentinelRunner(
        printer: printer,
        project: project,
        allTestsBuilder: stubAllTestsBuilder,
      );
    });

    group('createListener()', () {
      late Function(WatchEvent) listener;
      late WatchEvent event;
      late StubTestRunner testRunner;
      late bool isFlutter;

      setUp(() {
        testRunner = StubTestRunner();
      });

      group('for a non-flutter project', () {
        setUp(() {
          isFlutter = false;
        });

        group('with default parameters', () {
          setUp(() {
            listener = runner.createListener(
                testRunner: testRunner, isFlutter: isFlutter);
          });

          group(
              'when a non-dart file outside of interesting directories is modified',
              () {
            setUp(() async {
              event = WatchEvent(
                ChangeType.MODIFY,
                fs.path.join(rootDir, 'foo.txt'),
              );
              await listener(event);
            });

            test('it does not run test', () {
              expect(testRunner.ran, equals(false));
            });
          });

          group('when lib dart file is modified with no matching test file',
              () {
            setUp(() async {
              event = WatchEvent(
                ChangeType.MODIFY,
                fs.path.join(rootDir, 'lib', 'foo.dart'),
              );
              await listener(event);
            });

            test('it runs all tests', () {
              expect(
                testRunner.runs.first.match,
                equals(null),
              );
            });
          });

          group('when lib dart file is modified with matching test file', () {
            late File file;
            late File testFile;

            setUp(() async {
              file = await helper.createFile('lib/foo.dart');
              testFile = await helper.createFile('test/foo_test.dart');
              event = WatchEvent(ChangeType.MODIFY, file.path);
              await listener(event);
            });

            test('it runs the test file first', () {
              expect(
                testRunner.runs.first.match!.path,
                equals(testFile.path),
              );
            });

            test('it runs all tests after', () {
              expect(
                testRunner.runs[1].match,
                equals(null),
              );
            });
          });

          group('when a unit test file fails', () {
            late File file;

            setUp(() async {
              file = await helper.createFile('lib/foo.dart');
              await helper.createFile('test/foo_test.dart');
              testRunner.runReturns[0] = false;
              event = WatchEvent(ChangeType.MODIFY, file.path);
              await listener(event);
            });

            test('it does not run all tests', () {
              expect(testRunner.runs.length, equals(1));
            });
          });

          group('when a test file is modified', () {
            late File file;
            setUp(() async {
              file = await helper.createFile('test/foo_test.dart');
              event = WatchEvent(
                ChangeType.MODIFY,
                file.path,
              );
              await listener(event);
            });

            test('it runs test for matching file', () {
              expect(
                testRunner.runs.first.match,
                equals(
                  TestFileMatch(exists: true, path: file.path),
                ),
              );
            });

            test('it runs all tests after', () {
              expect(
                testRunner.runs[1].match,
                equals(null),
              );
            });
          });
        });

        group('with no integration', () {
          setUp(() {
            listener = runner.createListener(
                testRunner: testRunner, isFlutter: false, noIntegration: true);
          });

          group('when lib dart file is modified', () {
            setUp(() async {
              event = WatchEvent(
                ChangeType.MODIFY,
                fs.path.join(rootDir, 'lib', 'foo.dart'),
              );
              await listener(event);
            });

            test('it runs test ', () {
              expect(testRunner.ran, equals(true));
            });

            test('it passes noIntegration', () {
              expect(testRunner.passedNoIntegration, equals(true));
            });
          });
        });
      });

      group('for a flutter project', () {
        setUp(() {
          isFlutter = true;
        });

        group('and we allow integration tests', () {
          setUp(() {
            listener =
                runner.createListener(testRunner: testRunner, isFlutter: false);
          });

          test('it passes noIntegration', () {
            expect(testRunner.passedNoIntegration, equals(false));
          });
        });
      });
    });
  });
}

class StubTestRunner implements TestRunner {
  bool killed = false;
  bool ran = false;
  List<RunArgs> runs = [];
  Map<int, bool> runReturns = {};
  int currentRun = -1;
  bool terminated = false;
  bool passedNoIntegration = false;

  @override
  Future<bool> run({
    TestFileMatch? match,
    bool noIntegration = false,
    String device = 'all',
  }) async {
    runs.add(RunArgs(
      noIntegration: noIntegration,
      device: device,
      match: match,
    ));
    currentRun++;
    passedNoIntegration = noIntegration;
    return ran = runReturns[currentRun] ?? true;
  }

  @override
  bool get running => true;

  @override
  Future<bool> terminate() async {
    return terminated = true;
  }

  @override
  Future<bool> kill() async {
    return killed = true;
  }
}

class RunArgs extends Equatable {
  final TestFileMatch? match;
  final bool noIntegration;
  final String device;

  const RunArgs({
    required this.match,
    required this.noIntegration,
    required this.device,
  });

  @override
  List<Object?> get props => [match, noIntegration, device];
}

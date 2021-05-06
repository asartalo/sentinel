import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentinel/printer.dart';
import 'package:sentinel/project.dart';
import 'package:sentinel/sentinel_runner.dart';
import 'package:sentinel/test_file_match.dart';
import 'package:sentinel/test_runner.dart';
import 'package:test/test.dart';
import 'package:watcher/watcher.dart';

void main() {
  group(SentinelRunner, () {
    late SentinelRunner runner;
    late StubPrinter printer;
    late FileSystem fs;
    late String rootDir;
    late Project project;

    Future<void> stubAllTestsBuilder(Project project) async {}

    setUp(() {
      printer = StubPrinter();
      fs = MemoryFileSystem();
      rootDir = fs.systemTempDirectory.path;
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

      group('with default parameters', () {
        setUp(() {
          testRunner = StubTestRunner();
          listener =
              runner.createListener(testRunner: testRunner, isFlutter: false);
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

        group('when lib dart file is modified', () {
          setUp(() async {
            event = WatchEvent(
              ChangeType.MODIFY,
              fs.path.join(rootDir, 'lib', 'foo.dart'),
            );
            await listener(event);
          });

          test('it runs test', () {
            expect(testRunner.ran, equals(true));
          });
        });
      });

      group('with no integration', () {
        setUp(() {
          testRunner = StubTestRunner();
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

          test('it runs test', () {
            expect(testRunner.ran, equals(true));
          });

          test('it passes noIntegration', () {
            expect(testRunner.passedNoIntegration, equals(true));
          });
        });
      });
    });
  });
}

class StubTestRunner implements TestRunner {
  bool killed = false;
  bool ran = false;
  bool terminated = false;
  bool passedNoIntegration = false;

  @override
  Future<bool> run({
    TestFileMatch? match,
    bool noIntegration = false,
    String device = 'all',
  }) async {
    passedNoIntegration = noIntegration;
    return ran = true;
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

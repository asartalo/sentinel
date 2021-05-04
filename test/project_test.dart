import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentinel/project.dart';
import 'package:sentinel/test_file_match.dart';
import 'package:test/test.dart';

void main() {
  group('Project', () {
    late Project project;
    late FileSystem fs;
    late String rootDir;

    setUp(() {
      fs = MemoryFileSystem();
      rootDir = fs.systemTempDirectory.path;
      project = Project(rootDir, fs);
      // Create a pubspec.yaml;
    });

    group('.hasTestDir()', () {
      test('returns false when there is no test directory', () async {
        expect(await project.hasTestDir(), false);
      });

      test('returns true if rootDir has "test" directory', () async {
        await fs.systemTempDirectory.childDirectory('test').create();
        expect(await project.hasTestDir(), true);
      });
    });

    group('.hasIntegrationTestDir()', () {
      test('returns false when there is no integration test directory',
          () async {
        expect(await project.hasIntegrationTestDir(), false);
      });

      test('returns true if rootDir has "integration_test" directory',
          () async {
        await fs.systemTempDirectory
            .childDirectory('integration_test')
            .create();
        expect(await project.hasIntegrationTestDir(), true);
      });
    });

    group('.isFlutter()', () {
      test('returns false when there is no pubspec.yaml file', () async {
        expect(await project.isFlutter(), false);
      });

      test(
          'returns false if it has no reference to flutter field in pubspec.yaml',
          () async {
        final pubspec =
            await fs.systemTempDirectory.childFile('pubspec.yaml').create();
        await pubspec.writeAsString('''
name: my-project
dependencies:
  args: ^2.0.0
dev_dependencies:
  test: ^1.16.5
''');
        expect(await project.isFlutter(), false);
      });

      test('returns true when it has reference to a flutter', () async {
        final pubspec =
            await fs.systemTempDirectory.childFile('pubspec.yaml').create();
        await pubspec.writeAsString('''
name: my-project
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_driver:
    sdk: flutter
  flutter_test:
    sdk: flutter

flutter:
  assets:
    - data/
''');
        expect(await project.isFlutter(), true);
      });
    });

    Future<Directory> _createDirectory(String path) async {
      final paths = path.split('/');
      var currentPath = rootDir;
      late Directory currentDir;
      for (final part in paths) {
        currentPath = fs.path.join(currentPath, part);
        currentDir = await fs.directory(currentPath).create();
      }
      return currentDir;
    }

    Future<File> _createFile(String path) async {
      final dirPath = fs.path.dirname(path);
      var dir = fs.directory(dirPath);
      if (!await dir.exists()) {
        dir = await _createDirectory(dirPath);
      }
      return dir.childFile(fs.path.basename(path)).create();
    }

    group('.unitTestFor()', () {
      late File libFile;
      setUp(() async {
        libFile = await _createFile('lib/foo/bar.dart');
      });

      test('returns null if no test file is available', () async {
        expect(await project.unitTestFor(libFile.path), null);
      });

      test('returns file path of test file if it is available', () async {
        final testFile = await _createFile('test/foo/bar_test.dart');
        expect(await project.unitTestFor(libFile.path), testFile.path);
      });
    });

    group('.findMatchingTest()', () {
      test('it returns a mismatch if it is not a lib file', () async {
        expect(
          await project.findMatchingTest('some/file/that.dart'),
          TestFileMatch(
            exists: false,
            path: '',
          ),
        );
      });
      group('when file is a dart file under lib', () {
        late File libFile;
        setUp(() async {
          libFile = await _createFile('lib/foo/library.dart');
        });

        test('it returns a mismatch if a unit test does not exist', () async {
          expect(
            await project.findMatchingTest(libFile.path),
            TestFileMatch(
              exists: false,
              path: '',
            ),
          );
        });

        test('it returns a match if a unit test exists', () async {
          final testFile = await _createFile('test/foo/library_test.dart');
          expect(
            await project.findMatchingTest(libFile.path),
            TestFileMatch(
              exists: true,
              path: testFile.path,
            ),
          );
        });
      });

      group('when file is a unit test file', () {
        test('it returns a match if a unit test exists', () async {
          final testFile = await _createFile('test/foo/library_test.dart');
          expect(
            await project.findMatchingTest(testFile.path),
            TestFileMatch(
              exists: true,
              path: testFile.path,
            ),
          );
        });
      });

      group('when file is an integration test file', () {
        test('it returns a match', () async {
          final testFile =
              await _createFile('integration_test/screen_test.dart');
          expect(
            await project.findMatchingTest(testFile.path),
            TestFileMatch(
              exists: true,
              path: testFile.path,
              integrationTest: true,
            ),
          );
        });
      });
    });

    group('.getIntegrationTestFiles()', () {
      late String testFile1;
      late String testFile2;
      late List<String> files;

      setUp(() async {
        testFile1 = (await _createFile('integration_test/foo_test.dart')).path;
        testFile2 = (await _createFile('integration_test/bar_test.dart')).path;
        await _createFile(
            'integration_test/helper.dart'); // ignores helper files

        files = (await project.getIntegrationTestFiles())
            .map((e) => e.path)
            .toList();
      });

      test('it returns all test files', () {
        expect(files.length, equals(2));
        expect(files, contains(testFile1));
        expect(files, contains(testFile2));
      });
    });
  });
}

import 'dart:async';

import 'package:yaml/yaml.dart';
import 'package:file/file.dart';

const _testDir = 'test';
const _iTestDir = 'integration_test';
const _pubFile = 'pubspec.yaml';

class TestFileMatch {
  final bool exists;
  final String path;
  final bool integrationTest;
  TestFileMatch({
    required this.exists,
    required this.path,
    this.integrationTest = false,
  });

  @override
  String toString() {
    return 'path: $path,\nexists: $exists\nintegrationTest: $integrationTest';
  }

  @override
  bool operator ==(Object other) {
    if (other is TestFileMatch) {
      return exists == other.exists &&
          path == other.path &&
          integrationTest == other.integrationTest;
    }
    return false;
  }
}

class Project {
  final FileSystem fs;
  final String rootPath;
  late final RegExp _rootRegexp;

  Project(this.rootPath, this.fs)
      : _rootRegexp = RegExp('^${fs.path.separator}');

  File get pubspecFile => fs.file(_fullPath(_pubFile));

  Future<bool> _dirExists(String dirPath) {
    return fs.directory(_fullPath(dirPath)).exists();
  }

  String _fullPath(String path, [String? part2, String? part3]) {
    return fs.path.join(rootPath, path, part2, part3);
  }

  Future<bool> hasTestDir() => _dirExists(_testDir);
  Future<bool> hasIntegrationTestDir() => _dirExists(_iTestDir);
  String get integrationTesDirPath => _fullPath(_iTestDir);
  String get tesDirPath => _fullPath(_testDir);

  Future<bool> isFlutter() async {
    if (await pubspecFile.exists()) {
      final pubspec = loadYaml(await pubspecFile.readAsString());
      if (pubspec is YamlMap) {
        return pubspec.containsKey('flutter');
      }
    }
    return false;
  }

  Future<String?> unitTestFor(String path) async {
    final absolutePath = fs.path.absolute(path);
    final fromLibPath = absolutePath
        .replaceFirst(_fullPath('lib'), '')
        .replaceFirst(_rootRegexp, '');
    final testEquivalent = _fullPath(
      'test',
      fromLibPath.replaceFirst('.dart', '_test.dart'),
    );
    if (await fs.file(testEquivalent).exists()) {
      return testEquivalent;
    }
    return null;
  }

  final _testReg = RegExp(r'_test.dart$');
  final _libDartReg = RegExp(r'lib[\/\\].+\.dart$');
  Future<TestFileMatch> findMatchingTest(String path) async {
    if (_testReg.hasMatch(path)) {
      final integrationTest = path.startsWith(_fullPath(_iTestDir));
      return TestFileMatch(
        exists: true,
        path: path,
        integrationTest: integrationTest,
      );
    }
    if (_libDartReg.hasMatch(path)) {
      final testEquivalent = await unitTestFor(path);
      if (testEquivalent is String) {
        return TestFileMatch(exists: true, path: testEquivalent);
      }
    }
    return TestFileMatch(exists: false, path: '');
  }

  Future<List<File>> getIntegrationTestFiles() {
    final dir = fs.directory(integrationTesDirPath);
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
}

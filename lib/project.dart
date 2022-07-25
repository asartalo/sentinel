import 'dart:async';

import 'package:file/file.dart';
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'test_file_match.dart';

const _testDir = 'test';
const _iTestDir = 'integration_test';
const _pubFile = 'pubspec.yaml';
const _configFile = 'sentinel.yaml';

abstract class Project {
  FileSystem get fs;
  String get rootPath;
  Future<bool> hasTestDir();
  Future<bool> hasIntegrationTestDir();
  String get integrationTestDirPath;
  String get tesDirPath;
  Future<bool> isFlutter();
  Future<String?> unitTestFor(String path);
  Future<TestFileMatch> findMatchingTest(String path);
  Future<List<File>> getIntegrationTestFiles();
  File allIntegrationTestFile();
  String get allIntegrationTestFilePath;
  Directory getDir(String path);
  String getRelativePath(String path, {required String from});
  Future<List<String>> ignoredPaths();

  factory Project(String rootPath, FileSystem fs) => _Project(rootPath, fs);
}

final defaultConfig = Config(ignorePaths: const []);

class _Project implements Project {
  Config? _config;

  @override
  final FileSystem fs;

  @override
  final String rootPath;

  late final RegExp _rootRegexp;

  _Project(this.rootPath, this.fs)
      : _rootRegexp = RegExp('^${fs.path.separator}');

  File get pubspecFile => fs.file(_fullPath(_pubFile));

  Future<bool> _dirExists(String dirPath) {
    return fs.directory(_fullPath(dirPath)).exists();
  }

  String _fullPath(String path, [String? part2, String? part3]) {
    return fs.path.join(rootPath, path, part2, part3);
  }

  Future<Config> get config async {
    _config ??= await _loadConfiguration();

    return _config!;
  }

  Future<Config> _loadConfiguration() async {
    final configFile = fs.file(_fullPath(_configFile));
    if (await configFile.exists()) {
      final yamlConfig = loadYaml(await configFile.readAsString());
      if (yamlConfig is YamlMap) {
        final ignorePathsInYaml = yamlConfig['ignore'];
        List<String> ignorePaths = [];
        if (ignorePathsInYaml is YamlList) {
          ignorePaths =
              ignorePathsInYaml.map((element) => element.toString()).toList();
        }
        return Config(ignorePaths: ignorePaths);
      }
    }
    return defaultConfig;
  }

  @override
  Future<bool> hasTestDir() => _dirExists(_testDir);

  @override
  Future<bool> hasIntegrationTestDir() => _dirExists(_iTestDir);

  @override
  String get integrationTestDirPath => _fullPath(_iTestDir);

  @override
  String get tesDirPath => _fullPath(_testDir);

  @override
  Future<bool> isFlutter() async {
    if (await pubspecFile.exists()) {
      final pubspec = loadYaml(await pubspecFile.readAsString());
      if (pubspec is YamlMap) {
        return pubspec.containsKey('flutter');
      }
    }
    return false;
  }

  @override
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
  @override
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

  @override
  Future<List<File>> getIntegrationTestFiles() {
    final dir = fs.directory(integrationTestDirPath);
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

  @override
  File allIntegrationTestFile() {
    return fs.directory(integrationTestDirPath).childFile('all_tests.dart');
  }

  @override
  String get allIntegrationTestFilePath => fs.path.join(
        integrationTestDirPath,
        'all_tests.dart',
      );

  @override
  Directory getDir(String path) {
    return fs.directory(rootPath).childDirectory(path);
  }

  @override
  String getRelativePath(String path, {required String from}) {
    return fs.path.relative(path, from: from);
  }

  @override
  Future<List<String>> ignoredPaths() async {
    final conf = await config;
    return conf.ignorePaths;
  }
}

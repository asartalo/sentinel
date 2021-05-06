import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentinel/aitf_builder.dart';
import 'package:sentinel/project.dart';
import 'package:test/test.dart';

void main() {
  group(aitfBuilder, () {
    late FileSystem fs;
    late String rootDir;
    late Project project;

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

    setUp(() async {
      fs = MemoryFileSystem();
      rootDir = fs.systemTempDirectory.path;
      project = Project(rootDir, fs);
      await _createFile('integration_test/foo_test.dart');
      await _createFile('integration_test/baz/bar_test.dart');
      await _createFile('integration_test/helper.dart'); // ignores helper files
      await aitfBuilder(project);
    });

    test('it writes project files', () async {
      expect(await project.allIntegrationTestFile().readAsString(), equals('''
import 'package:integration_test/integration_test.dart';

import './foo_test.dart' as foo_test;
import './baz/bar_test.dart' as baz_bar_test;

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await foo_test.main();
  await baz_bar_test.main();
}
'''));
    });
  });
}

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentinel/aitf_builder.dart';
import 'package:sentinel/project.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group(aitfBuilder, () {
    late FileSystem fs;
    late String rootDir;
    late Project project;
    late FileHelpers helper;

    setUp(() async {
      fs = MemoryFileSystem();
      rootDir = fs.systemTempDirectory.path;
      project = Project(rootDir, fs);
      helper = FileHelpers(fs, rootDir);
      await helper.createFile('integration_test/foo_test.dart');
      await helper.createFile('integration_test/baz/bar_test.dart');
      await helper
          .createFile('integration_test/helper.dart'); // ignores helper files
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

import 'dart:io';

import 'project.dart';

final sep = Platform.pathSeparator;

Future<void> aitfBuilder(Project project) async {
  final testFiles = await project.getIntegrationTestFiles();
  final testDir = project.integrationTestDirPath;
  final imports = [
    "import 'package:integration_test/integration_test.dart';",
    "", // blank line
  ];
  final invokables = [];
  for (final testFile in testFiles) {
    var relativePath = project.getRelativePath(testFile.path, from: testDir);
    if (sep != '/') {
      relativePath = relativePath.replaceAll(sep, '/');
    }
    final invokable = invokableFromPath(relativePath);
    imports.add("import './$relativePath' as $invokable;");
    invokables.add('await $invokable.main();');
  }

  final allTestsFile = project.allIntegrationTestFile();
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

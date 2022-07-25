import 'package:file/file.dart';

class FileHelpers {
  FileSystem fs;
  String rootDir;

  FileHelpers(this.fs, this.rootDir);

  Future<Directory> createDirectory(String path) async {
    final paths = path.split('/');
    var currentPath = rootDir;
    late Directory currentDir;
    for (final part in paths) {
      currentPath = fs.path.join(currentPath, part);
      currentDir = await fs.directory(currentPath).create();
    }
    return currentDir;
  }

  Future<File> createFile(String path, [String? content]) async {
    final dirPath = fs.path.dirname(path);
    var dir = fs.directory(fs.path.join(rootDir, dirPath));
    if (!await dir.exists()) {
      dir = await createDirectory(dirPath);
    }
    final futureFile = dir.childFile(fs.path.basename(path)).create();
    if (content is String) {
      final file = await futureFile;
      return file.writeAsString(content);
    }
    return futureFile;
  }

  Future<void> deleteFile(String path) async {
    final file = fs.file(fs.path.join(rootDir, path));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

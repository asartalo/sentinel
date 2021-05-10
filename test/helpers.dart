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

  Future<File> createFile(String path) async {
    final dirPath = fs.path.dirname(path);
    var dir = fs.directory(dirPath);
    if (!await dir.exists()) {
      dir = await createDirectory(dirPath);
    }
    return dir.childFile(fs.path.basename(path)).create();
  }
}

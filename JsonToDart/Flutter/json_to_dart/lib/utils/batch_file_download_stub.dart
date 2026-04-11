import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// macOS/Desktop 平台批量文件下载实现
/// 下载文件并自动创建 req/resp/api 文件夹结构
Future<String?> downloadBatchFiles({
  required Map<String, String> reqFiles,
  required Map<String, String> respFiles,
  required String apiFileContent,
  required String apiFileName,
  required String exportRootName,
}) async {
  try {
    final String? outputDir = await FilePicker.getDirectoryPath(
      dialogTitle: '选择保存目录',
    );

    if (outputDir == null) {
      return null;
    }

    final Directory rootDir = Directory('$outputDir/$exportRootName');
    final Directory reqDir = Directory('${rootDir.path}/req');
    final Directory respDir = Directory('${rootDir.path}/resp');
    final Directory apiDir = Directory('${rootDir.path}/api');

    await rootDir.create(recursive: true);
    await reqDir.create(recursive: true);
    await respDir.create(recursive: true);
    await apiDir.create(recursive: true);

    for (final MapEntry<String, String> entry in reqFiles.entries) {
      final File file = File('${reqDir.path}/${entry.key}');
      await file.writeAsString(entry.value, encoding: utf8);
    }

    for (final MapEntry<String, String> entry in respFiles.entries) {
      final File file = File('${respDir.path}/${entry.key}');
      await file.writeAsString(entry.value, encoding: utf8);
    }

    final File apiFile = File('${apiDir.path}/$apiFileName');
    await apiFile.writeAsString(apiFileContent, encoding: utf8);

    return rootDir.path;
  } catch (e) {
    rethrow;
  }
}

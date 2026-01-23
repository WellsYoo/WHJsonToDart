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
}) async {
  try {
    // 让用户选择保存目录
    final String? outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择保存目录',
    );

    if (outputDir == null) {
      return null;
    }

    // 创建三个子目录
    final Directory reqDir = Directory('$outputDir/req');
    final Directory respDir = Directory('$outputDir/resp');
    final Directory apiDir = Directory('$outputDir/api');

    await reqDir.create(recursive: true);
    await respDir.create(recursive: true);
    await apiDir.create(recursive: true);

    // 保存所有请求 Model
    for (final MapEntry<String, String> entry in reqFiles.entries) {
      final File file = File('${reqDir.path}/${entry.key}');
      await file.writeAsString(entry.value, encoding: utf8);
    }

    // 保存所有响应 Model
    for (final MapEntry<String, String> entry in respFiles.entries) {
      final File file = File('${respDir.path}/${entry.key}');
      await file.writeAsString(entry.value, encoding: utf8);
    }

    // 保存 API 文件
    final File apiFile = File('${apiDir.path}/$apiFileName');
    await apiFile.writeAsString(apiFileContent, encoding: utf8);

    return outputDir;
  } catch (e) {
    rethrow;
  }
}

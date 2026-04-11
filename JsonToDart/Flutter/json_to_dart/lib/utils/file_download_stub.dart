import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// macOS/Desktop 平台文件下载实现
Future<void> downloadFile(String content, String fileName) async {
  try {
    // 让用户选择保存位置
    final String? outputPath = await FilePicker.saveFile(
      dialogTitle: '保存文件',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: <String>['dart'],
    );

    if (outputPath != null) {
      // 写入文件
      final File file = File(outputPath);
      await file.writeAsString(content);
      // 注意: 这里不能使用 SmartDialog,因为这是独立文件
      // 返回成功,由调用方处理提示
    }
  } catch (e) {
    // 抛出异常,由调用方处理
    rethrow;
  }
}

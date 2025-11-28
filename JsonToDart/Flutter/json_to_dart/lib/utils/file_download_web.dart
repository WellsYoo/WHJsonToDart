// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Web 平台文件下载实现
Future<void> downloadFile(String content, String fileName) async {
  final html.Blob blob = html.Blob(<dynamic>[content], 'text/plain', 'native');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  html.document.createElement('a')
    ..setAttribute('href', url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

/// Web 平台文件下载实现
Future<void> downloadFile(String content, String fileName) async {
  // 使用 UTF-8 编码,确保中文不乱码
  final List<int> bytes = utf8.encode(content);
  final html.Blob blob = html.Blob(<dynamic>[bytes], 'text/plain;charset=utf-8');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:json_to_dart/main_controller.dart';
import 'package:json_to_dart/models/openapi_document.dart';
import 'package:json_to_dart/utils/batch_api_generator.dart';
import 'package:json_to_dart/utils/batch_file_download_stub.dart'
    if (dart.library.html) 'package:json_to_dart/utils/batch_file_download_web.dart'
    as batch_download;
import 'package:json_to_dart/utils/file_download_stub.dart'
    if (dart.library.html) 'package:json_to_dart/utils/file_download_web.dart' as file_download;
import 'package:json_to_dart/utils/openapi_parser.dart';

/// OpenAPI 批量导入页面
class OpenApiImportPage extends StatefulWidget {
  const OpenApiImportPage({super.key});

  @override
  State<OpenApiImportPage> createState() => _OpenApiImportPageState();
}

class _OpenApiImportPageState extends State<OpenApiImportPage> {
  OpenApiParser? _parser;
  List<ParsedApiEndpoint>? _endpoints;
  bool _includeDeprecated = false;
  String _baseUrlInput = '';
  String _apiClassNameInput = '';

  final MainController _controller = Get.find<MainController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 16.0),
          Expanded(
            child: _parser == null ? _buildUploadArea() : _buildEndpointsList(),
          ),
          if (_parser != null && _endpoints != null) ...<Widget>[
            const SizedBox(height: 16.0),
            _buildBottomActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(Icons.upload_file, color: Colors.green.shade700, size: 20.0),
        ),
        const SizedBox(width: 12.0),
        const Text(
          'OpenAPI 批量导入',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            _controller.apiConfig.openApiMode.value = false;
            _controller.update();
          },
          icon: const Icon(Icons.arrow_back, size: 16.0),
          label: const Text('返回', style: TextStyle(fontSize: 13.0)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadArea() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cloud_upload_outlined, size: 80.0, color: Colors.grey.shade400),
            const SizedBox(height: 24.0),
            Text(
              '导入 OpenAPI 文档',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              '支持 OpenAPI 3.0/3.1 格式的 JSON 文件',
              style: TextStyle(fontSize: 14.0, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32.0),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件', style: TextStyle(fontSize: 14.0)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              '或拖拽文件到此处',
              style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final PlatformFile file = result.files.first;
        if (file.bytes != null) {
          final String jsonString = utf8.decode(file.bytes!, allowMalformed: true);
          _parseDocument(jsonString);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件读取失败: $e')),
      );
    }
  }

  void _parseDocument(String jsonString) {
    try {
      final OpenApiParser parser = OpenApiParser.fromJson(jsonString);
      final List<ParsedApiEndpoint> endpoints =
          parser.parseEndpoints(includeDeprecated: _includeDeprecated);

      setState(() {
        _parser = parser;
        _endpoints = endpoints;
        _apiClassNameInput = _toPascalCase(parser.document.info.title) + 'Api';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功解析 ${endpoints.length} 个接口')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文档解析失败: $e')),
      );
    }
  }

  Widget _buildEndpointsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildConfigSection(),
        const SizedBox(height: 16.0),
        _buildFilterBar(),
        const SizedBox(height: 12.0),
        Expanded(
          child: _buildEndpointsTable(),
        ),
      ],
    );
  }

  Widget _buildConfigSection() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.settings_outlined, size: 16.0, color: Colors.grey.shade700),
              const SizedBox(width: 8.0),
              Text(
                '生成配置',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildConfigTextField(
                  label: 'Base URL',
                  hint: "例如: MyEnvConfig.bizUrl + '/v1'",
                  value: _baseUrlInput,
                  onChanged: (String value) => _baseUrlInput = value,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildConfigTextField(
                  label: 'API 类名',
                  hint: '例如: PlanAdjustApi',
                  value: _apiClassNameInput,
                  onChanged: (String value) => _apiClassNameInput = value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTextField({
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 6.0),
        TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13.0),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final int selectedCount =
        _endpoints?.where((ParsedApiEndpoint e) => e.selected.value).length ?? 0;

    return Row(
      children: <Widget>[
        Text(
          '共 ${_endpoints?.length ?? 0} 个接口',
          style: TextStyle(fontSize: 13.0, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 8.0),
        Text(
          '已选 $selectedCount 个',
          style: const TextStyle(
            fontSize: 13.0,
            color: Colors.blue,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () {
            setState(() {
              _includeDeprecated = !_includeDeprecated;
              if (_parser != null) {
                _endpoints =
                    _parser!.parseEndpoints(includeDeprecated: _includeDeprecated);
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Checkbox(
                value: _includeDeprecated,
                onChanged: (bool? value) {
                  setState(() {
                    _includeDeprecated = value ?? false;
                    if (_parser != null) {
                      _endpoints =
                          _parser!.parseEndpoints(includeDeprecated: _includeDeprecated);
                    }
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const Text('包含废弃接口', style: TextStyle(fontSize: 12.0)),
            ],
          ),
        ),
        const SizedBox(width: 12.0),
        TextButton.icon(
          onPressed: _toggleSelectAll,
          icon: const Icon(Icons.checklist, size: 16.0),
          label: const Text('全选', style: TextStyle(fontSize: 12.0)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          ),
        ),
      ],
    );
  }

  void _toggleSelectAll() {
    if (_endpoints == null) {
      return;
    }

    final bool allSelected =
        _endpoints!.every((ParsedApiEndpoint e) => e.selected.value);

    setState(() {
      for (final ParsedApiEndpoint endpoint in _endpoints!) {
        endpoint.selected.value = !allSelected;
      }
    });
  }

  Widget _buildEndpointsTable() {
    if (_endpoints == null || _endpoints!.isEmpty) {
      return Center(
        child: Text(
          '没有找到接口',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListView.builder(
        itemCount: _endpoints!.length,
        itemBuilder: (BuildContext context, int index) {
          final ParsedApiEndpoint endpoint = _endpoints![index];
          return _buildEndpointItem(endpoint, index);
        },
      ),
    );
  }

  Widget _buildEndpointItem(ParsedApiEndpoint endpoint, int index) {
    return Obx(() {
      final bool isSelected = endpoint.selected.value;

      return InkWell(
        onTap: () {
          setState(() {
            endpoint.selected.value = !endpoint.selected.value;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: index == _endpoints!.length - 1 ? 0 : 1,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    endpoint.selected.value = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: _getMethodColor(endpoint.method),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  endpoint.method.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            endpoint.path,
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (endpoint.deprecated) ...<Widget>[
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                            child: const Text(
                              '已废弃',
                              style: TextStyle(
                                fontSize: 10.0,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      endpoint.summary,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  endpoint.methodName,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Color _getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'get':
        return Colors.green;
      case 'post':
        return Colors.blue;
      case 'put':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBottomActions() {
    final int selectedCount =
        _endpoints?.where((ParsedApiEndpoint e) => e.selected.value).length ?? 0;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : _generateAndCopyAll,
            icon: const Icon(Icons.content_copy, size: 18.0),
            label: const Text('复制所有代码', style: TextStyle(fontSize: 14.0)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: selectedCount == 0 ? null : _generateAndDownloadAll,
            icon: const Icon(Icons.download, size: 18.0),
            label: const Text(
              '生成并下载',
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateAndCopyAll() async {
    if (_parser == null || _endpoints == null) {
      return;
    }

    final List<ParsedApiEndpoint> selectedEndpoints =
        _endpoints!.where((ParsedApiEndpoint e) => e.selected.value).toList();

    if (selectedEndpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个接口')),
      );
      return;
    }

    if (_baseUrlInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Base URL')),
      );
      return;
    }

    if (_apiClassNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API 类名')),
      );
      return;
    }

    SmartDialog.showLoading(msg: '正在生成代码...');

    try {
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: _parser!,
        endpoints: selectedEndpoints,
        baseUrl: _baseUrlInput,
        apiClassName: _apiClassNameInput,
        modelGenerator: _controller.generateModelCodeAsync,
      );

      final BatchApiCodeResult result = await generator.generateAll();

      final StringBuffer allCode = StringBuffer();
      allCode.writeln('// ==================== Request Models ====================');
      allCode.writeln();
      for (final MapEntry<String, String> entry in result.reqFiles.entries) {
        allCode.writeln('// File: req/${entry.key}');
        allCode.writeln(entry.value);
        allCode.writeln();
      }

      allCode.writeln('// ==================== Response Models ====================');
      allCode.writeln();
      for (final MapEntry<String, String> entry in result.respFiles.entries) {
        allCode.writeln('// File: resp/${entry.key}');
        allCode.writeln(entry.value);
        allCode.writeln();
      }

      allCode.writeln('// ==================== API Methods ====================');
      allCode.writeln();
      allCode.writeln('// File: ${result.apiFileName}');
      allCode.writeln(result.apiFileContent);

      await Clipboard.setData(ClipboardData(text: allCode.toString()));

      SmartDialog.dismiss();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功生成 ${selectedEndpoints.length} 个接口的代码,已复制到剪贴板'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      SmartDialog.dismiss();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e')),
      );
    }
  }

  Future<void> _generateAndDownloadAll() async {
    if (_parser == null || _endpoints == null) {
      return;
    }

    final List<ParsedApiEndpoint> selectedEndpoints =
        _endpoints!.where((ParsedApiEndpoint e) => e.selected.value).toList();

    if (selectedEndpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个接口')),
      );
      return;
    }

    if (_baseUrlInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Base URL')),
      );
      return;
    }

    if (_apiClassNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API 类名')),
      );
      return;
    }

    SmartDialog.showLoading(msg: '正在生成代码...');

    try {
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: _parser!,
        endpoints: selectedEndpoints,
        baseUrl: _baseUrlInput,
        apiClassName: _apiClassNameInput,
        modelGenerator: _controller.generateModelCodeAsync,
      );

      final BatchApiCodeResult result = await generator.generateAll();

      final StringBuffer readme = StringBuffer();
      readme.writeln('# API 代码生成结果');
      readme.writeln();
      readme.writeln('## 文件结构');
      readme.writeln('```');
      readme.writeln('${_buildExportRootName()}/');
      readme.writeln('  req/                  # 请求 Model 目录');
      for (final String fileName in result.reqFiles.keys) {
        readme.writeln('    $fileName');
      }
      readme.writeln('  resp/                 # 响应 Model 目录');
      for (final String fileName in result.respFiles.keys) {
        readme.writeln('    $fileName');
      }
      readme.writeln('  api/                  # API 方法目录');
      readme.writeln('    ${result.apiFileName}');
      readme.writeln('```');
      readme.writeln();
      readme.writeln('## 使用说明');
      readme.writeln('1. 将 req/ 目录下的文件复制到项目的 lib/model/req/ 目录');
      readme.writeln('2. 将 resp/ 目录下的文件复制到项目的 lib/model/resp/ 目录');
      readme.writeln('3. 将 api/ 目录下的文件复制到项目的 lib/api/ 目录');
      readme.writeln('4. 根据需要调整 import 路径');

      final StringBuffer allContent = StringBuffer();
      allContent.writeln(readme.toString());
      allContent.writeln();
      allContent.writeln('---');
      allContent.writeln();
      allContent.writeln('# 完整代码');
      allContent.writeln();
      allContent.writeln('## Request Models');
      allContent.writeln();
      for (final MapEntry<String, String> entry in result.reqFiles.entries) {
        allContent.writeln('### ${entry.key}');
        allContent.writeln('```dart');
        allContent.writeln(entry.value);
        allContent.writeln('```');
        allContent.writeln();
      }

      allContent.writeln('## Response Models');
      allContent.writeln();
      for (final MapEntry<String, String> entry in result.respFiles.entries) {
        allContent.writeln('### ${entry.key}');
        allContent.writeln('```dart');
        allContent.writeln(entry.value);
        allContent.writeln('```');
        allContent.writeln();
      }

      allContent.writeln('## API Methods');
      allContent.writeln();
      allContent.writeln('### ${result.apiFileName}');
      allContent.writeln('```dart');
      allContent.writeln(result.apiFileContent);
      allContent.writeln('```');

      await Clipboard.setData(ClipboardData(text: allContent.toString()));

      SmartDialog.dismiss();

      if (!mounted) {
        return;
      }

      _showGeneratedCodePreview(result, allContent.toString());
    } catch (e) {
      SmartDialog.dismiss();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e')),
      );
    }
  }

  void _showGeneratedCodePreview(BatchApiCodeResult result, String allContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle, color: Colors.green, size: 28.0),
                    const SizedBox(width: 12.0),
                    const Text(
                      '代码生成完成',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '生成统计',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(_buildGeneratedSummary(result)),
                      const SizedBox(height: 8.0),
                      const Text(
                        '✓ 所有代码已复制到剪贴板',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text(
                  '代码预览',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        allContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: allContent));
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                        icon: const Icon(Icons.content_copy, size: 18.0),
                        label: const Text('复制代码'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final String fileName =
                              '${_buildExportRootName()}_generated_${DateTime.now().millisecondsSinceEpoch}.md';
                          await file_download.downloadFile(allContent, fileName);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已下载: $fileName')),
                          );
                        },
                        icon: const Icon(Icons.download, size: 18.0),
                        label: const Text('下载目录说明 MD'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadSeparateFiles(result),
                        icon: const Icon(Icons.folder_zip, size: 18.0),
                        label: const Text('导出分目录文件'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check, size: 18.0),
                        label: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadSeparateFiles(BatchApiCodeResult result) async {
    try {
      final String? outputDir = await batch_download.downloadBatchFiles(
        reqFiles: result.reqFiles,
        respFiles: result.respFiles,
        apiFileContent: result.apiFileContent,
        apiFileName: result.apiFileName,
        exportRootName: _buildExportRootName(),
      );

      if (outputDir != null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到: $outputDir\n'
                '目录结构: req/、resp/、api/\n'
                '包含: req/ (${result.reqFiles.length}个), '
                'resp/ (${result.respFiles.length}个), '
                'api/ (1个)'),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    } catch (e) {
      // 降级到逐个下载 (Web)
    }

    int downloadCount = 0;

    for (final MapEntry<String, String> entry in result.reqFiles.entries) {
      await file_download.downloadFile(entry.value, entry.key);
      downloadCount++;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    for (final MapEntry<String, String> entry in result.respFiles.entries) {
      await file_download.downloadFile(entry.value, entry.key);
      downloadCount++;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    await file_download.downloadFile(result.apiFileContent, result.apiFileName);
    downloadCount++;

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已下载 $downloadCount 个文件\n'
            '提示: 请手动整理到 ${_buildExportRootName()}/req、resp、api 文件夹'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _buildGeneratedSummary(BatchApiCodeResult result) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('请求 Model: ${result.reqFiles.length} 个');
    buffer.writeln('响应 Model: ${result.respFiles.length} 个');
    buffer.writeln(
      'API 方法: ${_endpoints!.where((ParsedApiEndpoint e) => e.selected.value).length} 个',
    );
    if (result.skippedReqModels.isNotEmpty) {
      buffer.writeln('未生成请求 Model: ${result.skippedReqModels.join(', ')}');
    }
    if (result.skippedRespModels.isNotEmpty) {
      buffer.writeln('未生成响应 Model: ${result.skippedRespModels.join(', ')}');
    }
    return buffer.toString().trimRight();
  }

  String _buildExportRootName() {
    final String sanitized =
        _apiClassNameInput.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return sanitized.isEmpty ? 'openapi_export' : sanitized;
  }

  String _toPascalCase(String input) {
    if (input.isEmpty) {
      return input;
    }
    final String cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final List<String> parts = cleaned.split('_');
    return parts.map((String s) {
      if (s.isEmpty) {
        return s;
      }
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }).join();
  }
}

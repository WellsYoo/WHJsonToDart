import 'dart:convert';

import 'package:json_to_dart/models/openapi_document.dart';
import 'package:json_to_dart/utils/openapi_parser.dart';
import 'package:json_to_dart_library/json_to_dart_library.dart';

/// 批量 API 代码生成结果
class BatchApiCodeResult {
  BatchApiCodeResult({
    required this.reqFiles,
    required this.respFiles,
    required this.apiFileContent,
    required this.apiFileName,
  });

  /// 请求 Model 文件 (文件名 -> 代码内容)
  final Map<String, String> reqFiles;

  /// 响应 Model 文件 (文件名 -> 代码内容)
  final Map<String, String> respFiles;

  /// API 文件内容
  final String apiFileContent;

  /// API 文件名
  final String apiFileName;
}

/// 批量 API 代码生成器
class BatchApiCodeGenerator {
  BatchApiCodeGenerator({
    required this.parser,
    required this.endpoints,
    required this.baseUrl,
    required this.apiClassName,
    required this.modelGenerator,
  });

  final OpenApiParser parser;
  final List<ParsedApiEndpoint> endpoints;
  final String baseUrl;
  final String apiClassName;
  final Function(String jsonString, String className) modelGenerator;

  /// 批量生成所有代码
  Future<BatchApiCodeResult> generateAll() async {
    final Map<String, String> reqFiles = <String, String>{};
    final Map<String, String> respFiles = <String, String>{};
    final CustomStringBuffer apiContent = CustomStringBuffer();

    // 生成 API 类头部
    _generateApiClassHeader(apiContent);

    // 遍历所有选中的接口
    for (final ParsedApiEndpoint endpoint in endpoints) {
      if (!endpoint.selected.value) {
        continue;
      }

      print('Processing endpoint: ${endpoint.path} ${endpoint.method}');
      print('  hasResponse: ${endpoint.hasResponse}');
      print('  responseSchemaRef: ${endpoint.responseSchemaRef}');

      // 生成请求 Model
      if (endpoint.requestSchemaRef != null) {
        final String? reqModelCode = await _generateRequestModel(endpoint);
        if (reqModelCode != null) {
          final String fileName = _toSnakeCase(endpoint.classNamePrefix) + '_req.dart';
          reqFiles[fileName] = reqModelCode;
          print('  Generated request model: $fileName');
        }
      }

      // 生成响应 Model
      if (endpoint.hasResponse && endpoint.responseSchemaRef != null) {
        print('  Attempting to generate response model...');
        final String? respModelCode = await _generateResponseModel(endpoint);
        if (respModelCode != null) {
          final String fileName = _toSnakeCase(endpoint.classNamePrefix) + '_resp.dart';
          respFiles[fileName] = respModelCode;
          print('  Generated response model: $fileName');
        } else {
          print('  Failed to generate response model');
        }
      } else {
        print('  Skipped response model: hasResponse=${endpoint.hasResponse}');
      }

      // 生成 API 方法
      _generateApiMethod(apiContent, endpoint);
      apiContent.writeLine('');
    }

    // 生成 API 类尾部
    apiContent.writeLine('}');

    final String apiFileName = _toSnakeCase(apiClassName) + '.dart';

    print('Summary: ${reqFiles.length} req files, ${respFiles.length} resp files');

    return BatchApiCodeResult(
      reqFiles: reqFiles,
      respFiles: respFiles,
      apiFileContent: apiContent.toString(),
      apiFileName: apiFileName,
    );
  }

  /// 生成 API 类头部
  void _generateApiClassHeader(CustomStringBuffer sb) {
    sb.writeLine('// ignore_for_file: always_specify_types');
    sb.writeLine('');
    sb.writeLine('class $apiClassName {');
    sb.writeLine('  factory $apiClassName() => const $apiClassName._();');
    sb.writeLine('');
    sb.writeLine('  const $apiClassName._();');
    sb.writeLine('');
    sb.writeLine('  static final String _baseUrl = $baseUrl;');
    sb.writeLine('');
  }

  /// 生成请求 Model
  Future<String?> _generateRequestModel(ParsedApiEndpoint endpoint) async {
    final Map<String, dynamic>? schemaJson = parser.resolveSchemaToJson(endpoint.requestSchemaRef);
    if (schemaJson == null) {
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    final String className = endpoint.classNamePrefix + 'Req';

    return await modelGenerator(jsonString, className);
  }

  /// 生成响应 Model
  Future<String?> _generateResponseModel(ParsedApiEndpoint endpoint) async {
    print('    _generateResponseModel called');
    print('    responseSchemaRef: ${endpoint.responseSchemaRef}');

    // 从 ResponseData«T» 中提取真实的响应类型
    final String? dataTypeRef = parser.extractDataTypeFromResponse(endpoint.responseSchemaRef);
    print('    Extracted dataTypeRef: $dataTypeRef');

    // 如果没有提取到 dataTypeRef,尝试直接使用 responseSchemaRef
    final String? schemaRef = dataTypeRef ?? endpoint.responseSchemaRef;
    print('    Using schemaRef: $schemaRef');

    if (schemaRef == null) {
      print('    schemaRef is null, returning null');
      return null;
    }

    final Map<String, dynamic>? schemaJson = parser.resolveSchemaToJson(schemaRef);
    print('    Resolved schema JSON: ${schemaJson != null ? "success (${schemaJson.length} properties)" : "null"}');

    if (schemaJson == null || schemaJson.isEmpty) {
      print('    Schema JSON is null or empty, returning null');
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    print('    JSON string length: ${jsonString.length}');

    final String className = endpoint.classNamePrefix + 'Resp';
    print('    Generating model with className: $className');

    final String? result = await modelGenerator(jsonString, className);
    print('    Model generation result: ${result != null ? "success (${result.length} chars)" : "null"}');

    return result;
  }

  /// 生成 API 方法
  void _generateApiMethod(CustomStringBuffer sb, ParsedApiEndpoint endpoint) {
    final String methodName = endpoint.methodName;
    final String urlConstantName = _getUrlConstantName(endpoint);
    final String requestClassName = endpoint.classNamePrefix + 'Req';
    final String responseClassName = endpoint.classNamePrefix + 'Resp';

    // 生成 URL 常量
    sb.writeLine('  /// ${endpoint.summary} ${endpoint.method.toUpperCase()}');
    if (endpoint.useSprintfUrl) {
      final String sprintfUrl = _pathToSprintfFormat(endpoint.path);
      sb.writeLine('  static final String $urlConstantName = \'\$_baseUrl$sprintfUrl\';');
    } else {
      sb.writeLine('  static final String $urlConstantName = \'\$_baseUrl${endpoint.path}\';');
    }
    sb.writeLine('');

    // 生成请求方法
    switch (endpoint.method.toLowerCase()) {
      case 'get':
        _generateGetMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
      case 'post':
        _generatePostMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
      case 'put':
        _generatePutMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
      case 'delete':
        _generateDeleteMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
    }
  }

  /// 生成 GET 方法
  void _generateGetMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    if (endpoint.useSprintfUrl) {
      // 使用 sprintf (路径参数)
      sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
      sb.writeLine('    required String? id,');
      sb.writeLine('  }) async {');
      sb.writeLine('    var response = await MyHttpUtil().get(');
      sb.writeLine('      sprintf($urlConstantName, [id]),');
      sb.writeLine('    );');
      sb.writeLine('    return $responseClassName.fromJson(response);');
      sb.writeLine('  }');
    } else {
      // 普通 GET 请求
      sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      sb.writeLine('    var response = await MyHttpUtil().get(');
      sb.writeLine('      $urlConstantName,');
      sb.writeLine('      queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
      sb.writeLine('    );');
      sb.writeLine('    return $responseClassName.fromJson(response);');
      sb.writeLine('  }');
    }
  }

  /// 生成 POST 方法
  void _generatePostMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    if (endpoint.hasResponse) {
      sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      sb.writeLine('    var response = await MyHttpUtil().post($urlConstantName,');
      sb.writeLine('        data: req.toJson()..removeWhere((key, value) => value == null));');
      sb.writeLine('    return $responseClassName.fromJson(response);');
      sb.writeLine('  }');
    } else {
      sb.writeLine('  Future<dynamic> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      sb.writeLine('    return await MyHttpUtil().post($urlConstantName,');
      sb.writeLine('        data: req.toJson()..removeWhere((key, value) => value == null));');
      sb.writeLine('  }');
    }
  }

  /// 生成 PUT 方法
  void _generatePutMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    // PUT 通常用于更新操作,使用 Form 模式
    sb.writeLine('  Future<bool> ${methodName}Req({');
    sb.writeLine('    required $requestClassName req,');
    sb.writeLine('  }) async {');
    sb.writeLine('    bool result = await MyActionUtil.form().handle(');
    sb.writeLine('      action: () async {');
    sb.writeLine('        return await MyHttpUtil().put($urlConstantName,');
    sb.writeLine('            data: req.toJson()..removeWhere((key, value) => value == null));');
    sb.writeLine('      },');
    sb.writeLine('      loadText: \'提交中\',');
    sb.writeLine('      successText: \'操作成功\',');
    sb.writeLine('      errorText: \'操作失败\',');
    sb.writeLine('    );');
    sb.writeLine('    return result;');
    sb.writeLine('  }');
  }

  /// 生成 DELETE 方法
  void _generateDeleteMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    if (endpoint.useSprintfUrl) {
      // 使用 sprintf (路径参数)
      sb.writeLine('  Future<bool> ${methodName}Req({');
      sb.writeLine('    required String? id,');
      sb.writeLine('  }) async {');
      sb.writeLine('    bool result = await MyActionUtil.form().handle(');
      sb.writeLine('      action: () async {');
      sb.writeLine('        return await MyHttpUtil().delete(');
      sb.writeLine('          sprintf($urlConstantName, [id]),');
      sb.writeLine('        );');
      sb.writeLine('      },');
      sb.writeLine('      loadText: \'删除中\',');
      sb.writeLine('      successText: \'删除成功\',');
      sb.writeLine('      errorText: \'删除失败\',');
      sb.writeLine('    );');
      sb.writeLine('    return result;');
      sb.writeLine('  }');
    } else {
      sb.writeLine('  Future<dynamic> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      sb.writeLine('    return await MyHttpUtil().delete($urlConstantName);');
      sb.writeLine('  }');
    }
  }

  /// 获取 URL 常量名称
  String _getUrlConstantName(ParsedApiEndpoint endpoint) {
    String name = endpoint.methodName;

    // 如果以 Req 结尾,移除它
    if (name.endsWith('Req')) {
      name = name.substring(0, name.length - 3);
    } else if (name.endsWith('req')) {
      name = name.substring(0, name.length - 3);
    }

    // 添加 Url 后缀
    if (!name.endsWith('Url')) {
      name += 'Url';
    }

    return name;
  }

  /// 将路径转为 sprintf 格式
  /// 例如: /v1/plan/adjust/{id} -> /v1/plan/adjust/%s
  String _pathToSprintfFormat(String path) {
    return path.replaceAllMapped(RegExp(r'\{[^}]+\}'), (Match m) => '%s');
  }

  /// 转换为 snake_case
  String _toSnakeCase(String input) {
    if (input.isEmpty) {
      return '';
    }
    return input
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (Match match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp('^_'), '');
  }

  /// 将 JSON 对象转为字符串
  String _jsonToString(Map<String, dynamic> json) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}

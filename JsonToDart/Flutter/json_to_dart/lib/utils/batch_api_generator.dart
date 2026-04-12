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
    required this.skippedReqModels,
    required this.skippedRespModels,
  });

  /// 请求 Model 文件 (文件名 -> 代码内容)
  final Map<String, String> reqFiles;

  /// 响应 Model 文件 (文件名 -> 代码内容)
  final Map<String, String> respFiles;

  /// API 文件内容
  final String apiFileContent;

  /// API 文件名
  final String apiFileName;

  /// 未生成的请求 Model
  final List<String> skippedReqModels;

  /// 未生成的响应 Model
  final List<String> skippedRespModels;
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
  final Future<String?> Function(String jsonString, String className) modelGenerator;

  /// 批量生成所有代码
  Future<BatchApiCodeResult> generateAll() async {
    final Map<String, String> reqFiles = <String, String>{};
    final Map<String, String> respFiles = <String, String>{};
    final List<String> skippedReqModels = <String>[];
    final List<String> skippedRespModels = <String>[];
    final CustomStringBuffer apiContent = CustomStringBuffer();

    _generateApiClassHeader(apiContent);

    for (final ParsedApiEndpoint endpoint in endpoints) {
      if (!endpoint.selected.value) {
        continue;
      }

      final String? reqModelCode = await _generateRequestModel(endpoint);
      if (reqModelCode != null) {
        final String fileName = _toSnakeCase(_normalizedClassNamePrefix(endpoint)) + '_req.dart';
        reqFiles[fileName] = reqModelCode;
      } else if (_usesRequestModel(endpoint) &&
          (endpoint.requestSchemaRef != null || parser.resolveRequestSchemaToJsonForEndpoint(endpoint) != null)) {
        skippedReqModels.add(endpoint.classNamePrefix);
      }

      String? respModelCode;
      bool hasGeneratedResponseModel = false;
      if (endpoint.hasResponse) {
        respModelCode = await _generateResponseModel(endpoint);
        if (respModelCode != null) {
          final String fileName = _toSnakeCase(_normalizedClassNamePrefix(endpoint)) + '_resp.dart';
          respFiles[fileName] = respModelCode;
          hasGeneratedResponseModel = true;
        } else if (endpoint.responseSchemaRef != null ||
            parser.resolveResponseSchemaToJsonForEndpoint(endpoint) != null) {
          skippedRespModels.add(endpoint.classNamePrefix);
        }
      }

      _generateApiMethod(apiContent, endpoint, hasGeneratedResponseModel);
      apiContent.writeLine('');
    }

    apiContent.writeLine('}');

    final String apiFileName = _toSnakeCase(apiClassName) + '.dart';

    return BatchApiCodeResult(
      reqFiles: reqFiles,
      respFiles: respFiles,
      apiFileContent: apiContent.toString(),
      apiFileName: apiFileName,
      skippedReqModels: skippedReqModels,
      skippedRespModels: skippedRespModels,
    );
  }

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

  Future<String?> _generateRequestModel(ParsedApiEndpoint endpoint) async {
    if (!_usesRequestModel(endpoint)) {
      return null;
    }

    final Map<String, dynamic>? schemaJson =
        parser.resolveRequestSchemaToJsonForEndpoint(endpoint);
    if (schemaJson == null || schemaJson.isEmpty) {
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    final String className = _normalizedClassNamePrefix(endpoint) + 'Req';

    return await modelGenerator(jsonString, className);
  }

  Future<String?> _generateResponseModel(ParsedApiEndpoint endpoint) async {
    final String? dataTypeRef =
        parser.extractDataTypeFromResponse(endpoint.responseSchemaRef);

    Map<String, dynamic>? schemaJson;
    if (dataTypeRef != null) {
      schemaJson = parser.resolveSchemaToJson(dataTypeRef);
    } else {
      schemaJson = parser.resolveResponseSchemaToJsonForEndpoint(endpoint);
    }

    if (schemaJson == null || schemaJson.isEmpty) {
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    final String className = _normalizedClassNamePrefix(endpoint) + 'Resp';

    return await modelGenerator(jsonString, className);
  }

  void _generateApiMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    bool hasGeneratedResponseModel,
  ) {
    final String methodName = endpoint.methodName;
    final String urlConstantName = _getUrlConstantName(endpoint);
    final String requestClassName = _normalizedClassNamePrefix(endpoint) + 'Req';
    final String responseClassName = _normalizedClassNamePrefix(endpoint) + 'Resp';

    sb.writeLine('  /// ${endpoint.summary} ${endpoint.method.toUpperCase()}');
    if (endpoint.useSprintfUrl) {
      final String sprintfUrl = _pathToSprintfFormat(endpoint.path);
      sb.writeLine('  static final String $urlConstantName = \'\$_baseUrl$sprintfUrl\';');
    } else {
      sb.writeLine('  static final String $urlConstantName = \'\$_baseUrl${endpoint.path}\';');
    }
    sb.writeLine('');

    switch (endpoint.method.toLowerCase()) {
      case 'get':
        _generateGetMethod(
          sb,
          endpoint,
          methodName,
          urlConstantName,
          requestClassName,
          responseClassName,
          hasGeneratedResponseModel,
        );
        break;
      case 'post':
        _generatePostMethod(
          sb,
          endpoint,
          methodName,
          urlConstantName,
          requestClassName,
          responseClassName,
          hasGeneratedResponseModel,
        );
        break;
      case 'put':
        _generatePutMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
      case 'delete':
        _generateDeleteMethod(sb, endpoint, methodName, urlConstantName, requestClassName, responseClassName);
        break;
    }
  }

  bool _usesRequestModel(ParsedApiEndpoint endpoint) {
    return endpoint.requestSchemaRef != null ||
        (!endpoint.useSprintfUrl && endpoint.requestParameterCount >= 3);
  }

  bool _usesInlineParameters(ParsedApiEndpoint endpoint) {
    return !endpoint.useSprintfUrl &&
        endpoint.requestSchemaRef == null &&
        endpoint.requestParameterCount > 0 &&
        endpoint.requestParameterCount < 3;
  }

  String _normalizedClassNamePrefix(ParsedApiEndpoint endpoint) {
    final String prefix = endpoint.classNamePrefix;
    if (prefix.startsWith('Api') && prefix.length > 3) {
      return prefix.substring(3);
    }
    return prefix;
  }

  String _toParameterName(String input) {
    final List<String> parts = input.split('_').where((String part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return input;
    }
    return parts.first + parts.skip(1).map((String part) => part[0].toUpperCase() + part.substring(1)).join();
  }

  void _writeInlineMethodParameters(CustomStringBuffer sb, ParsedApiEndpoint endpoint) {
    for (final Parameter parameter in endpoint.queryParameters ?? <Parameter>[]) {
      final String type = _dartTypeFromSchema(parameter.schema);
      final String parameterName = _toParameterName(parameter.name);
      final String requiredKeyword = parameter.required == true ? 'required ' : '';
      sb.writeLine('        ${requiredKeyword}$type $parameterName,');
    }
  }

  void _writeInlineQueryParameters(CustomStringBuffer sb, ParsedApiEndpoint endpoint) {
    sb.writeLine('      queryParameters: <String, dynamic>{');
    for (final Parameter parameter in endpoint.queryParameters ?? <Parameter>[]) {
      final String parameterName = _toParameterName(parameter.name);
      sb.writeLine("        '${parameter.name}': $parameterName,");
    }
    sb.writeLine('      }..removeWhere((key, value) => value == null),');
  }

  String _dartTypeFromSchema(Map<String, dynamic>? schema) {
    final String? type = schema?['type'] as String?;
    switch (type) {
      case 'integer':
        return 'int?';
      case 'number':
        return 'double?';
      case 'boolean':
        return 'bool?';
      default:
        return 'String?';
    }
  }

  void _generateGetMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
    bool hasGeneratedResponseModel,
  ) {
    if (endpoint.useSprintfUrl) {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
        sb.writeLine('    required String? id,');
        sb.writeLine('  }) async {');
        sb.writeLine('    var response = await MyHttpUtil().get(');
        sb.writeLine('      sprintf($urlConstantName, [id]),');
        sb.writeLine('    );');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<dynamic> ${methodName}Req({');
        sb.writeLine('    required String? id,');
        sb.writeLine('  }) async {');
        sb.writeLine('    return await MyHttpUtil().get(');
        sb.writeLine('      sprintf($urlConstantName, [id]),');
        sb.writeLine('    );');
        sb.writeLine('  }');
      }
    } else if (_usesRequestModel(endpoint)) {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
        sb.writeLine('    required $requestClassName req,');
        sb.writeLine('  }) async {');
        sb.writeLine('    var response = await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        sb.writeLine('      queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('    );');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<dynamic> ${methodName}Req({');
        sb.writeLine('    required $requestClassName req,');
        sb.writeLine('  }) async {');
        sb.writeLine('    return await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        sb.writeLine('      queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('    );');
        sb.writeLine('  }');
      }
    } else if (_usesInlineParameters(endpoint)) {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
        _writeInlineMethodParameters(sb, endpoint);
        sb.writeLine('  }) async {');
        sb.writeLine('    var response = await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        _writeInlineQueryParameters(sb, endpoint);
        sb.writeLine('    );');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<dynamic> ${methodName}Req({');
        _writeInlineMethodParameters(sb, endpoint);
        sb.writeLine('  }) async {');
        sb.writeLine('    return await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        _writeInlineQueryParameters(sb, endpoint);
        sb.writeLine('    );');
        sb.writeLine('  }');
      }
    } else {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req() async {');
        sb.writeLine('    var response = await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        sb.writeLine('    );');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<dynamic> ${methodName}Req() async {');
        sb.writeLine('    return await MyHttpUtil().get(');
        sb.writeLine('      $urlConstantName,');
        sb.writeLine('    );');
        sb.writeLine('  }');
      }
    }
  }

  void _generatePostMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
    bool hasGeneratedResponseModel,
  ) {
    if (_usesRequestModel(endpoint)) {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
        sb.writeLine('    required $requestClassName req,');
        sb.writeLine('  }) async {');
        sb.writeLine('    var response = await MyHttpUtil().post($urlConstantName,');
        if (endpoint.queryParameters != null && endpoint.queryParameters!.isNotEmpty) {
          sb.writeLine('        queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
          sb.writeLine('    );');
        } else {
          sb.writeLine('        data: req.toJson()..removeWhere((key, value) => value == null));');
        }
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<void> ${methodName}Req({');
        sb.writeLine('    required $requestClassName req,');
        sb.writeLine('  }) async {');
        sb.writeLine('    await MyHttpUtil().post($urlConstantName,');
        if (endpoint.queryParameters != null && endpoint.queryParameters!.isNotEmpty) {
          sb.writeLine('        queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
          sb.writeLine('    );');
        } else {
          sb.writeLine('        data: req.toJson()..removeWhere((key, value) => value == null));');
        }
        sb.writeLine('  }');
      }
    } else if (_usesInlineParameters(endpoint)) {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req({');
        _writeInlineMethodParameters(sb, endpoint);
        sb.writeLine('  }) async {');
        sb.writeLine('    var response = await MyHttpUtil().post($urlConstantName,');
        _writeInlineQueryParameters(sb, endpoint);
        sb.writeLine('    );');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<void> ${methodName}Req({');
        _writeInlineMethodParameters(sb, endpoint);
        sb.writeLine('  }) async {');
        sb.writeLine('    await MyHttpUtil().post($urlConstantName,');
        _writeInlineQueryParameters(sb, endpoint);
        sb.writeLine('    );');
        sb.writeLine('  }');
      }
    } else {
      if (hasGeneratedResponseModel) {
        sb.writeLine('  Future<$responseClassName?> ${methodName}Req() async {');
        sb.writeLine('    var response = await MyHttpUtil().post($urlConstantName);');
        sb.writeLine('    return $responseClassName.fromJson(response);');
        sb.writeLine('  }');
      } else {
        sb.writeLine('  Future<void> ${methodName}Req() async {');
        sb.writeLine('    await MyHttpUtil().post($urlConstantName);');
        sb.writeLine('  }');
      }
    }
  }
  void _generatePutMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    if (_usesRequestModel(endpoint)) {
      sb.writeLine('  Future<void> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      if (endpoint.queryParameters != null && endpoint.queryParameters!.isNotEmpty) {
        sb.writeLine('    await MyHttpUtil().put($urlConstantName,');
        sb.writeLine('      queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('    );');
      } else {
        sb.writeLine('    await MyHttpUtil().put($urlConstantName,');
        sb.writeLine('        data: req.toJson()..removeWhere((key, value) => value == null));');
      }
      sb.writeLine('  }');
    } else if (_usesInlineParameters(endpoint)) {
      sb.writeLine('  Future<void> ${methodName}Req({');
      _writeInlineMethodParameters(sb, endpoint);
      sb.writeLine('  }) async {');
      sb.writeLine('    await MyHttpUtil().put($urlConstantName,');
      _writeInlineQueryParameters(sb, endpoint);
      sb.writeLine('    );');
      sb.writeLine('  }');
    } else {
      sb.writeLine('  Future<void> ${methodName}Req() async {');
      sb.writeLine('    await MyHttpUtil().put($urlConstantName);');
      sb.writeLine('  }');
    }
  }

  void _generateDeleteMethod(
    CustomStringBuffer sb,
    ParsedApiEndpoint endpoint,
    String methodName,
    String urlConstantName,
    String requestClassName,
    String responseClassName,
  ) {
    if (endpoint.useSprintfUrl) {
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
    } else if (_usesRequestModel(endpoint)) {
      sb.writeLine('  Future<void> ${methodName}Req({');
      sb.writeLine('    required $requestClassName req,');
      sb.writeLine('  }) async {');
      if (endpoint.queryParameters != null && endpoint.queryParameters!.isNotEmpty) {
        sb.writeLine('    await MyHttpUtil().delete($urlConstantName,');
        sb.writeLine('      queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('    );');
      } else {
        sb.writeLine('    await MyHttpUtil().delete($urlConstantName);');
      }
      sb.writeLine('  }');
    } else if (_usesInlineParameters(endpoint)) {
      sb.writeLine('  Future<void> ${methodName}Req({');
      _writeInlineMethodParameters(sb, endpoint);
      sb.writeLine('  }) async {');
      sb.writeLine('    await MyHttpUtil().delete($urlConstantName,');
      _writeInlineQueryParameters(sb, endpoint);
      sb.writeLine('    );');
      sb.writeLine('  }');
    } else {
      sb.writeLine('  Future<void> ${methodName}Req() async {');
      sb.writeLine('    await MyHttpUtil().delete($urlConstantName);');
      sb.writeLine('  }');
    }
  }

  String _getUrlConstantName(ParsedApiEndpoint endpoint) {
    String name = endpoint.methodName;

    if (name.endsWith('Req')) {
      name = name.substring(0, name.length - 3);
    } else if (name.endsWith('req')) {
      name = name.substring(0, name.length - 3);
    }

    if (!name.endsWith('Url')) {
      name += 'Url';
    }

    return name;
  }

  String _pathToSprintfFormat(String path) {
    return path.replaceAllMapped(RegExp(r'\{[^}]+\}'), (Match m) => '%s');
  }

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

  String _jsonToString(Map<String, dynamic> json) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}

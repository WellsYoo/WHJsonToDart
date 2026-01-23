import 'dart:convert';
import 'package:json_to_dart/models/openapi_document.dart';

/// OpenAPI 文档解析器
class OpenApiParser {
  OpenApiParser(this.document);

  final OpenApiDocument document;

  /// 解析所有 API 接口
  List<ParsedApiEndpoint> parseEndpoints({bool includeDeprecated = false}) {
    final List<ParsedApiEndpoint> endpoints = <ParsedApiEndpoint>[];

    for (final MapEntry<String, PathItem> pathEntry in document.paths.entries) {
      final String path = pathEntry.key;
      final PathItem pathItem = pathEntry.value;

      // 遍历该路径下的所有 HTTP 方法
      for (final MapEntry<String, Operation> operationEntry in pathItem.operations) {
        final String method = operationEntry.key;
        final Operation operation = operationEntry.value;

        // 跳过已废弃的接口 (如果不包含废弃接口)
        if (!includeDeprecated && operation.deprecated) {
          continue;
        }

        // 提取路径参数
        final List<Parameter>? pathParameters = operation.parameters
            ?.where((Parameter p) => p.paramIn == 'path')
            .toList();

        // 提取请求体 schema ref
        String? requestSchemaRef;
        if (operation.requestBody != null) {
          requestSchemaRef = operation.requestBody!.schemaRef;
        }

        // 提取响应 schema ref
        String? responseSchemaRef;
        bool hasResponse = true;
        if (operation.responses != null && operation.responses!.containsKey('200')) {
          final ApiResponse? response200 = operation.responses!['200'];
          if (response200 != null) {
            responseSchemaRef = response200.schemaRef;

            // 判断是否有响应数据 (通过 example 判断)
            final dynamic example = response200.example;
            if (example is Map && example['data'] != null) {
              // 检查 data 类型
              final dynamic dataValue = example['data'];
              // 如果 data 是空字符串或 null,认为无响应
              if (dataValue == '' || dataValue == null || dataValue == false) {
                hasResponse = false;
              }
            }
          }
        }

        endpoints.add(ParsedApiEndpoint(
          path: path,
          method: method,
          summary: operation.summary,
          deprecated: operation.deprecated,
          description: operation.description,
          tags: operation.tags,
          requestSchemaRef: requestSchemaRef,
          responseSchemaRef: responseSchemaRef,
          pathParameters: pathParameters,
          hasResponse: hasResponse,
        ));
      }
    }

    return endpoints;
  }

  /// 通过 $ref 获取 schema JSON
  Map<String, dynamic>? getSchemaByRef(String? ref) {
    if (ref == null) {
      return null;
    }
    return document.components.getSchemaByRef(ref);
  }

  /// 解析 schema 并转为 JSON 示例 (用于生成 Model)
  Map<String, dynamic>? resolveSchemaToJson(String? schemaRef) {
    if (schemaRef == null) {
      return null;
    }

    final Map<String, dynamic>? schema = getSchemaByRef(schemaRef);
    if (schema == null) {
      return null;
    }

    return _schemaToJson(schema);
  }

  /// 递归将 schema 转为 JSON 示例
  Map<String, dynamic> _schemaToJson(Map<String, dynamic> schema) {
    final Map<String, dynamic> result = <String, dynamic>{};

    // 处理对象类型
    final dynamic typeValue = schema['type'];
    if (typeValue == 'object' || typeValue == null) {
      // 如果没有指定 type,也尝试读取 properties
      final Map<String, dynamic>? properties = schema['properties'] as Map<String, dynamic>?;
      if (properties != null) {
        for (final MapEntry<String, dynamic> prop in properties.entries) {
          final String propName = prop.key;
          final dynamic propValue = prop.value;

          // 确保 propValue 是 Map
          if (propValue is! Map<String, dynamic>) {
            result[propName] = '';
            continue;
          }

          final Map<String, dynamic> propSchema = propValue;

          // 处理 $ref
          if (propSchema.containsKey('\$ref')) {
            final dynamic ref = propSchema['\$ref'];
            if (ref is String) {
              final Map<String, dynamic>? refSchema = getSchemaByRef(ref);
              if (refSchema != null) {
                result[propName] = _schemaToJson(refSchema);
                continue;
              }
            }
          }

          // 根据类型生成示例值
          result[propName] = _generateExampleValue(propSchema);
        }
      }
    }

    return result;
  }

  /// 根据 schema 类型生成示例值
  dynamic _generateExampleValue(Map<String, dynamic> schema) {
    // 优先使用 example
    if (schema.containsKey('example')) {
      return schema['example'];
    }

    // 处理 $ref
    if (schema.containsKey('\$ref')) {
      final dynamic ref = schema['\$ref'];
      if (ref is String) {
        final Map<String, dynamic>? refSchema = getSchemaByRef(ref);
        if (refSchema != null) {
          return _schemaToJson(refSchema);
        }
      }
      return null;
    }

    final dynamic typeValue = schema['type'];
    final dynamic formatValue = schema['format'];

    // 安全地转换为 String
    final String? type = typeValue is String ? typeValue : null;
    final String? format = formatValue is String ? formatValue : null;

    // 如果 type 不是 String,使用默认值
    if (type == null) {
      return '';
    }

    switch (type) {
      case 'string':
        return '';
      case 'integer':
        if (format == 'int64') {
          return 0;
        }
        return 0;
      case 'number':
        return 0.0;
      case 'boolean':
        return false;
      case 'array':
        final Map<String, dynamic>? items = schema['items'] as Map<String, dynamic>?;
        if (items != null) {
          return <dynamic>[_generateExampleValue(items)];
        }
        return <dynamic>[];
      case 'object':
        return _schemaToJson(schema);
      default:
        return '';
    }
  }

  /// 从 ResponseData«T» 中提取真实的响应类型
  /// 例如: ResponseData«PlanAdjustResponse» -> PlanAdjustResponse
  String? extractDataTypeFromResponse(String? responseSchemaRef) {
    if (responseSchemaRef == null) {
      return null;
    }

    print('      extractDataTypeFromResponse: $responseSchemaRef');

    final Map<String, dynamic>? responseSchema = getSchemaByRef(responseSchemaRef);
    print('      Got responseSchema: ${responseSchema != null ? "yes" : "null"}');

    if (responseSchema == null) {
      return null;
    }

    // 查找 properties.data.$ref
    final Map<String, dynamic>? properties = responseSchema['properties'] as Map<String, dynamic>?;
    print('      Got properties: ${properties != null ? "yes (${properties.keys.length} keys)" : "null"}');

    if (properties == null) {
      return null;
    }

    final Map<String, dynamic>? dataProperty = properties['data'] as Map<String, dynamic>?;
    print('      Got dataProperty: ${dataProperty != null ? "yes" : "null"}');

    if (dataProperty == null) {
      return null;
    }

    // 处理 $ref
    if (dataProperty.containsKey('\$ref')) {
      final dynamic ref = dataProperty['\$ref'];
      print('      Found $ref in data: $ref');
      if (ref is String) {
        return ref;
      }
      return null;
    }

    // 处理 type: array (列表响应)
    final dynamic typeValue = dataProperty['type'];
    print('      data type: $typeValue');

    if (typeValue == 'array') {
      final Map<String, dynamic>? items = dataProperty['items'] as Map<String, dynamic>?;
      if (items != null && items.containsKey('\$ref')) {
        final dynamic ref = items['\$ref'];
        print('      Found $ref in array items: $ref');
        if (ref is String) {
          return ref;
        }
      }
    }

    return null;
  }

  /// 从文件路径加载 OpenAPI 文档
  static Future<OpenApiParser> fromFile(String filePath) async {
    // 此方法在 Web 环境不可用,由调用方处理文件读取
    throw UnsupportedError('Use fromJson instead');
  }

  /// 从 JSON 字符串解析 OpenAPI 文档
  static OpenApiParser fromJson(String jsonString) {
    final dynamic json = jsonDecode(jsonString);
    final OpenApiDocument document = OpenApiDocument.fromJson(json as Map<String, dynamic>);
    return OpenApiParser(document);
  }
}

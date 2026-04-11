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

      for (final MapEntry<String, Operation> operationEntry in pathItem.operations) {
        final String method = operationEntry.key;
        final Operation operation = operationEntry.value;

        if (!includeDeprecated && operation.deprecated) {
          continue;
        }

        final List<Parameter>? pathParameters =
            operation.parameters?.where((Parameter p) => p.paramIn == 'path').toList();

        String? requestSchemaRef;
        if (operation.requestBody != null) {
          requestSchemaRef = operation.requestBody!.schemaRef;
        }

        String? responseSchemaRef;
        bool hasResponse = true;
        if (operation.responses != null && operation.responses!.containsKey('200')) {
          final ApiResponse? response200 = operation.responses!['200'];
          if (response200 != null) {
            responseSchemaRef = response200.schemaRef;
            final dynamic example = response200.example;
            if (example is Map && example['data'] != null) {
              final dynamic dataValue = example['data'];
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

  Map<String, dynamic>? getSchemaByRef(String? ref) {
    if (ref == null) {
      return null;
    }
    return document.components.getSchemaByRef(ref);
  }

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

  Map<String, dynamic>? resolveRequestSchemaToJsonForEndpoint(
    ParsedApiEndpoint endpoint,
  ) {
    if (endpoint.requestSchemaRef != null) {
      return resolveSchemaToJson(endpoint.requestSchemaRef);
    }

    final Operation? operation = _findOperation(endpoint.path, endpoint.method);
    final Map<String, dynamic>? schema = operation?.requestBody?.schema;
    if (schema == null) {
      return null;
    }
    return schemaToJson(schema);
  }

  Map<String, dynamic>? resolveResponseSchemaToJson(
    String path,
    String method,
  ) {
    final Operation? operation = _findOperation(path, method);
    final ApiResponse? response = operation?.responses?['200'];
    final Map<String, dynamic>? schema = response?.schema;
    if (schema == null) {
      return null;
    }

    if (response?.schemaRef != null) {
      return resolveSchemaToJson(response!.schemaRef);
    }

    return schemaToJson(schema);
  }

  Map<String, dynamic>? resolveResponseSchemaToJsonForEndpoint(
    ParsedApiEndpoint endpoint,
  ) {
    if (endpoint.responseSchemaRef != null) {
      return resolveSchemaToJson(endpoint.responseSchemaRef);
    }
    return resolveResponseSchemaToJson(endpoint.path, endpoint.method);
  }

  Map<String, dynamic> schemaToJson(Map<String, dynamic> schema) {
    return _schemaToJson(schema);
  }

  Map<String, dynamic> _schemaToJson(Map<String, dynamic> schema) {
    final Map<String, dynamic> result = <String, dynamic>{};

    final dynamic typeValue = schema['type'];
    if (typeValue == 'object' || typeValue == null) {
      final Map<String, dynamic>? properties = schema['properties'] as Map<String, dynamic>?;
      if (properties != null) {
        for (final MapEntry<String, dynamic> prop in properties.entries) {
          final String propName = prop.key;
          final dynamic propValue = prop.value;

          if (propValue is! Map<String, dynamic>) {
            result[propName] = '';
            continue;
          }

          final Map<String, dynamic> propSchema = propValue;
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

          result[propName] = _generateExampleValue(propSchema);
        }
      }
    }

    return result;
  }

  dynamic _generateExampleValue(Map<String, dynamic> schema) {
    if (schema.containsKey('example')) {
      return schema['example'];
    }

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

    if (typeValue is List<dynamic>) {
      final Iterable<String> types = typeValue.whereType<String>();
      if (types.contains('object')) {
        return _schemaToJson(<String, dynamic>{...schema, 'type': 'object'});
      }
      if (types.contains('array')) {
        return _generateExampleValue(<String, dynamic>{...schema, 'type': 'array'});
      }
      if (types.contains('string')) {
        return '';
      }
      if (types.contains('integer')) {
        return 0;
      }
      if (types.contains('number')) {
        return 0.0;
      }
      if (types.contains('boolean')) {
        return false;
      }
      if (types.contains('null')) {
        return null;
      }
    }

    if (typeValue == 'null') {
      return null;
    }

    final String? type = typeValue is String ? typeValue : null;
    final String? format = formatValue is String ? formatValue : null;

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

  String? extractDataTypeFromResponse(String? responseSchemaRef) {
    if (responseSchemaRef == null) {
      return null;
    }

    final Map<String, dynamic>? responseSchema = getSchemaByRef(responseSchemaRef);
    if (responseSchema == null) {
      return null;
    }

    final Map<String, dynamic>? properties = responseSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      return null;
    }

    final Map<String, dynamic>? dataProperty = properties['data'] as Map<String, dynamic>?;
    if (dataProperty == null) {
      return null;
    }

    if (dataProperty.containsKey('\$ref')) {
      final dynamic ref = dataProperty['\$ref'];
      if (ref is String) {
        return ref;
      }
      return null;
    }

    final dynamic typeValue = dataProperty['type'];
    if (typeValue == 'array') {
      final Map<String, dynamic>? items = dataProperty['items'] as Map<String, dynamic>?;
      if (items != null && items.containsKey('\$ref')) {
        final dynamic ref = items['\$ref'];
        if (ref is String) {
          return ref;
        }
      }
    }

    return null;
  }

  Operation? _findOperation(String path, String method) {
    final PathItem? pathItem = document.paths[path];
    if (pathItem == null) {
      return null;
    }

    switch (method.toLowerCase()) {
      case 'get':
        return pathItem.get;
      case 'post':
        return pathItem.post;
      case 'put':
        return pathItem.put;
      case 'delete':
        return pathItem.delete;
      default:
        return null;
    }
  }

  static Future<OpenApiParser> fromFile(String filePath) async {
    throw UnsupportedError('Use fromJson instead');
  }

  static OpenApiParser fromJson(String jsonString) {
    final dynamic json = jsonDecode(jsonString);
    final OpenApiDocument document = OpenApiDocument.fromJson(json as Map<String, dynamic>);
    return OpenApiParser(document);
  }
}

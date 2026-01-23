import 'package:get/get.dart';

/// OpenAPI 文档模型
class OpenApiDocument {
  OpenApiDocument({
    required this.openapi,
    required this.info,
    required this.paths,
    required this.components,
  });

  factory OpenApiDocument.fromJson(Map<String, dynamic> json) {
    return OpenApiDocument(
      openapi: json['openapi'] as String? ?? '',
      info: ApiInfo.fromJson(json['info'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      paths: (json['paths'] as Map<String, dynamic>?)
              ?.map((String key, dynamic value) =>
                  MapEntry<String, PathItem>(key, PathItem.fromJson(value as Map<String, dynamic>)))
              .cast<String, PathItem>() ??
          <String, PathItem>{},
      components: Components.fromJson(json['components'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );
  }

  final String openapi;
  final ApiInfo info;
  final Map<String, PathItem> paths;
  final Components components;
}

/// API 基础信息
class ApiInfo {
  ApiInfo({
    required this.title,
    required this.version,
    this.description,
  });

  factory ApiInfo.fromJson(Map<String, dynamic> json) {
    return ApiInfo(
      title: json['title'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  final String title;
  final String version;
  final String? description;
}

/// 路径项 (一个 URL 对应的所有 HTTP 方法)
class PathItem {
  PathItem({
    this.get,
    this.post,
    this.put,
    this.delete,
  });

  factory PathItem.fromJson(Map<String, dynamic> json) {
    return PathItem(
      get: json['get'] != null ? Operation.fromJson(json['get'] as Map<String, dynamic>) : null,
      post: json['post'] != null ? Operation.fromJson(json['post'] as Map<String, dynamic>) : null,
      put: json['put'] != null ? Operation.fromJson(json['put'] as Map<String, dynamic>) : null,
      delete: json['delete'] != null ? Operation.fromJson(json['delete'] as Map<String, dynamic>) : null,
    );
  }

  final Operation? get;
  final Operation? post;
  final Operation? put;
  final Operation? delete;

  List<MapEntry<String, Operation>> get operations {
    final List<MapEntry<String, Operation>> result = <MapEntry<String, Operation>>[];
    if (get != null) {
      result.add(MapEntry<String, Operation>('get', get!));
    }
    if (post != null) {
      result.add(MapEntry<String, Operation>('post', post!));
    }
    if (put != null) {
      result.add(MapEntry<String, Operation>('put', put!));
    }
    if (delete != null) {
      result.add(MapEntry<String, Operation>('delete', delete!));
    }
    return result;
  }
}

/// API 操作 (单个 HTTP 方法)
class Operation {
  Operation({
    required this.summary,
    required this.deprecated,
    this.description,
    this.tags,
    this.parameters,
    this.requestBody,
    this.responses,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      summary: json['summary'] as String? ?? '',
      deprecated: json['deprecated'] as bool? ?? false,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      parameters: (json['parameters'] as List<dynamic>?)
          ?.map((dynamic e) => Parameter.fromJson(e as Map<String, dynamic>))
          .toList(),
      requestBody: json['requestBody'] != null
          ? RequestBody.fromJson(json['requestBody'] as Map<String, dynamic>)
          : null,
      responses: (json['responses'] as Map<String, dynamic>?)
          ?.map((String key, dynamic value) =>
              MapEntry<String, ApiResponse>(key, ApiResponse.fromJson(value as Map<String, dynamic>)))
          .cast<String, ApiResponse>(),
    );
  }

  final String summary;
  final bool deprecated;
  final String? description;
  final List<String>? tags;
  final List<Parameter>? parameters;
  final RequestBody? requestBody;
  final Map<String, ApiResponse>? responses;
}

/// 参数
class Parameter {
  Parameter({
    required this.name,
    required this.paramIn,
    this.description,
    this.required,
    this.schema,
  });

  factory Parameter.fromJson(Map<String, dynamic> json) {
    return Parameter(
      name: json['name'] as String? ?? '',
      paramIn: json['in'] as String? ?? '',
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
      schema: json['schema'] as Map<String, dynamic>?,
    );
  }

  final String name;
  final String paramIn; // path, query, header
  final String? description;
  final bool? required;
  final Map<String, dynamic>? schema;
}

/// 请求体
class RequestBody {
  RequestBody({
    this.content,
  });

  factory RequestBody.fromJson(Map<String, dynamic> json) {
    return RequestBody(
      content: json['content'] as Map<String, dynamic>?,
    );
  }

  final Map<String, dynamic>? content;

  /// 获取请求体的 schema ref
  String? get schemaRef {
    if (content == null) {
      return null;
    }
    final Map<String, dynamic>? applicationJson = content!['application/json'] as Map<String, dynamic>?;
    if (applicationJson == null) {
      return null;
    }
    final Map<String, dynamic>? schema = applicationJson['schema'] as Map<String, dynamic>?;
    if (schema == null) {
      return null;
    }
    final dynamic ref = schema['\$ref'];
    if (ref is String) {
      return ref;
    }
    return null;
  }
}

/// 响应
class ApiResponse {
  ApiResponse({
    this.description,
    this.content,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      description: json['description'] as String?,
      content: json['content'] as Map<String, dynamic>?,
    );
  }

  final String? description;
  final Map<String, dynamic>? content;

  /// 获取响应的 schema ref
  String? get schemaRef {
    if (content == null) {
      return null;
    }
    final Map<String, dynamic>? applicationJson = content!['application/json'] as Map<String, dynamic>?;
    if (applicationJson == null) {
      return null;
    }
    final Map<String, dynamic>? schema = applicationJson['schema'] as Map<String, dynamic>?;
    if (schema == null) {
      return null;
    }
    final dynamic ref = schema['\$ref'];
    if (ref is String) {
      return ref;
    }
    return null;
  }

  /// 获取响应的 example
  dynamic get example {
    if (content == null) {
      return null;
    }
    final Map<String, dynamic>? applicationJson = content!['application/json'] as Map<String, dynamic>?;
    if (applicationJson == null) {
      return null;
    }
    return applicationJson['example'];
  }
}

/// 组件定义 (Schema, Response, etc.)
class Components {
  Components({
    this.schemas,
  });

  factory Components.fromJson(Map<String, dynamic> json) {
    return Components(
      schemas: json['schemas'] as Map<String, dynamic>?,
    );
  }

  final Map<String, dynamic>? schemas;

  /// 通过 $ref 获取 schema
  Map<String, dynamic>? getSchemaByRef(String ref) {
    // ref 格式: #/components/schemas/SchemaName
    if (!ref.startsWith('#/components/schemas/')) {
      return null;
    }
    String schemaName = ref.replaceFirst('#/components/schemas/', '');

    // URL 解码 (处理 %C2%AB 等编码)
    schemaName = Uri.decodeComponent(schemaName);

    if (schemas == null) {
      return null;
    }

    // 直接查找
    Map<String, dynamic>? result = schemas![schemaName] as Map<String, dynamic>?;
    if (result != null) {
      return result;
    }

    // 如果直接查找失败,尝试匹配键名
    // 问题: Apifox 导出的 JSON 中 « » 字符使用了错误的 UTF-8 编码
    // URL 解码后: « = 171, » = 187 (单字节)
    // JSON 键中: « = 194+171, » = 194+187 (双字节 UTF-8)
    // 需要将 171 转换为 194+171, 187 转换为 194+187
    String normalizedName = schemaName;
    if (schemaName.contains('«') || schemaName.contains('»')) {
      // 将单字节 Latin-1 字符转换为 UTF-8 双字节表示
      final List<int> bytes = <int>[];
      for (final int code in schemaName.codeUnits) {
        if (code == 171 || code == 187) {
          // « (171) -> 0xC2 0xAB (194, 171)
          // » (187) -> 0xC2 0xBB (194, 187)
          bytes.add(194);
          bytes.add(code);
        } else if (code < 128) {
          bytes.add(code);
        } else if (code < 2048) {
          bytes.add(192 + (code >> 6));
          bytes.add(128 + (code & 63));
        } else {
          bytes.add(224 + (code >> 12));
          bytes.add(128 + ((code >> 6) & 63));
          bytes.add(128 + (code & 63));
        }
      }
      // 将字节序列解码为字符串 (Latin-1 解码,保持字节值)
      normalizedName = String.fromCharCodes(bytes);
    }

    // 使用规范化的名称再次查找
    result = schemas![normalizedName] as Map<String, dynamic>?;
    return result;
  }
}

/// 解析后的 API 接口信息 (用于 UI 展示)
class ParsedApiEndpoint {
  ParsedApiEndpoint({
    required this.path,
    required this.method,
    required this.summary,
    required this.deprecated,
    this.description,
    this.tags,
    this.requestSchemaRef,
    this.responseSchemaRef,
    this.pathParameters,
    this.hasResponse = true,
  });

  final String path;
  final String method; // get, post, put, delete
  final String summary;
  final bool deprecated;
  final String? description;
  final List<String>? tags;
  final String? requestSchemaRef;
  final String? responseSchemaRef;
  final List<Parameter>? pathParameters;
  final bool hasResponse; // 是否有响应参数

  /// 是否选中 (用于批量生成)
  final RxBool selected = true.obs;

  /// 生成的方法名
  String get methodName {
    // 从 path 和 summary 生成方法名
    // 例如: /v1/plan/adjust/receive + "接收" -> receive
    // 例如: /v1/plan/adjust/search + "列表" -> search
    String name = path.split('/').lastWhere((String s) => s.isNotEmpty && !s.startsWith('{'));

    // 移除特殊字符
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    // 转为驼峰
    return _toCamelCase(name);
  }

  /// 生成的类名前缀 (用于 Req/Resp)
  String get classNamePrefix {
    // 从 path 生成类名
    // 例如: /v1/plan/adjust/receive -> PlanAdjustReceive
    final List<String> parts = path.split('/').where((String s) => s.isNotEmpty && !s.startsWith('{')).toList();

    // 移除版本号 (v1, v2 等)
    parts.removeWhere((String s) => RegExp(r'^v\d+$').hasMatch(s));

    // 转为 PascalCase
    return parts.map((String s) => _toPascalCase(s)).join();
  }

  /// 是否使用 sprintf URL (包含路径参数)
  bool get useSprintfUrl {
    return pathParameters != null && pathParameters!.isNotEmpty;
  }

  String _toCamelCase(String input) {
    if (input.isEmpty) {
      return input;
    }
    return input[0].toLowerCase() + input.substring(1);
  }

  String _toPascalCase(String input) {
    if (input.isEmpty) {
      return input;
    }
    // 移除特殊字符并转为 PascalCase
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

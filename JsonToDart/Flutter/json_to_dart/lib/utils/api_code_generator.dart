import 'package:json_to_dart/models/api_config.dart';
import 'package:json_to_dart_library/json_to_dart_library.dart';

/// API 代码生成结果
class ApiCodeGenerationResult {
  ApiCodeGenerationResult({
    required this.requestModelCode,
    required this.responseModelCode,
    required this.apiMethodCode,
    required this.requestFileName,
    required this.responseFileName,
    required this.apiFileName,
  });

  /// 请求参数 Model 代码
  final String requestModelCode;

  /// 响应参数 Model 代码
  final String responseModelCode;

  /// API 方法代码
  final String apiMethodCode;

  /// 请求参数文件名
  final String requestFileName;

  /// 响应参数文件名
  final String responseFileName;

  /// API 文件名
  final String apiFileName;
}

/// API 代码生成器
class ApiCodeGenerator {
  /// 生成 API 相关代码
  static ApiCodeGenerationResult? generateApiCode({
    required ApiConfig apiConfig,
    required String requestModelCode,
    required String responseModelCode,
  }) {
    if (apiConfig.methodName.value.isEmpty) {
      return null;
    }

    final String apiMethodCode = _generateApiMethod(
      apiConfig: apiConfig,
      requestClassName: apiConfig.requestClassName,
      responseClassName: apiConfig.responseClassName,
    );

    return ApiCodeGenerationResult(
      requestModelCode: requestModelCode,
      responseModelCode: responseModelCode,
      apiMethodCode: apiMethodCode,
      requestFileName: apiConfig.requestFileName,
      responseFileName: apiConfig.responseFileName,
      apiFileName: apiConfig.apiFileName,
    );
  }

  /// 生成 API 方法代码
  static String _generateApiMethod({
    required ApiConfig apiConfig,
    required String requestClassName,
    required String responseClassName,
  }) {
    final CustomStringBuffer sb = CustomStringBuffer();

    // 不生成导入语句,直接生成 API 代码片段
    _generateApiSnippet(sb, apiConfig, requestClassName, responseClassName);

    return sb.toString();
  }

  /// 生成 API 代码片段 (不包含类结构)
  static void _generateApiSnippet(
    CustomStringBuffer sb,
    ApiConfig apiConfig,
    String requestClassName,
    String responseClassName,
  ) {
    final String methodName = apiConfig.methodName.value;
    final String comment = apiConfig.methodComment.value.isNotEmpty
        ? apiConfig.methodComment.value
        : _getMethodComment(apiConfig);

    // 生成 URL 常量注释和定义
    sb.writeLine('/// $comment ${apiConfig.httpMethod.value.methodName}');

    // 生成 URL 常量
    if (apiConfig.baseUrl.value.isNotEmpty) {
      sb.writeLine("static final String $methodName = _baseUrl + '${apiConfig.apiUrl.value}';");
    } else {
      sb.writeLine("static final String $methodName = '${apiConfig.apiUrl.value}';");
    }
    sb.writeLine('');

    // 生成请求方法
    _generateRequestMethod(
      sb,
      apiConfig,
      methodName,
      requestClassName,
      responseClassName,
    );
  }

  /// 获取方法注释
  static String _getMethodComment(ApiConfig apiConfig) {
    String name = apiConfig.methodName.value;
    if (name.endsWith('Req') || name.endsWith('req')) {
      name = name.substring(0, name.length - 3);
    }
    // 转换为中文或保持原样
    return name;
  }

  /// 生成请求方法
  static void _generateRequestMethod(
    CustomStringBuffer sb,
    ApiConfig apiConfig,
    String methodName,
    String requestClassName,
    String responseClassName,
  ) {
    final HttpMethod httpMethod = apiConfig.httpMethod.value;

    switch (httpMethod) {
      case HttpMethod.post:
        _generatePostMethod(
            sb, methodName, requestClassName, responseClassName, apiConfig);
        break;
      case HttpMethod.get:
        _generateGetMethod(
            sb, methodName, requestClassName, responseClassName, apiConfig);
        break;
      case HttpMethod.put:
        _generatePutMethod(
            sb, methodName, requestClassName, responseClassName, apiConfig);
        break;
      case HttpMethod.delete:
        _generateDeleteMethod(
            sb, methodName, requestClassName, responseClassName, apiConfig);
        break;
    }
  }

  /// 生成 POST 方法
  static void _generatePostMethod(
    CustomStringBuffer sb,
    String methodName,
    String requestClassName,
    String responseClassName,
    ApiConfig apiConfig,
  ) {
    // 获取实际的方法名,避免重复 Req
    final String actualMethodName = _getActualMethodName(methodName);

    if (apiConfig.requestMode.value == ApiRequestMode.direct) {
      // 直接请求模式
      if (apiConfig.hasResponse.value) {
        // 有响应参数
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyHttpUtil().post($methodName,');
        sb.writeLine(
            '      data: req.toJson()..removeWhere((key, value) => value == null));');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      } else {
        // 无响应参数,返回动态类型
        sb.writeLine('static Future<dynamic> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  return await MyHttpUtil().post($methodName,');
        sb.writeLine(
            '      data: req.toJson()..removeWhere((key, value) => value == null));');
        sb.writeLine('}');
      }
    } else {
      // Form 请求模式
      sb.writeLine('static Future<bool> $actualMethodName({');
      sb.writeLine('  required $requestClassName req,');
      sb.writeLine('}) async {');
      sb.writeLine('  bool result = await MyActionUtil.form().handle(');
      sb.writeLine('    action: () async {');
      sb.writeLine('      return await MyHttpUtil().post($methodName,');
      sb.writeLine(
          '          data: req.toJson()..removeWhere((key, value) => value == null));');
      sb.writeLine('    },');
      sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
      sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
      sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
      sb.writeLine('  );');
      sb.writeLine('  return result;');
      sb.writeLine('}');
    }
  }

  /// 获取实际的方法名 (避免重复 Req 后缀)
  static String _getActualMethodName(String methodName) {
    // 如果已经以 Req 结尾,直接返回
    if (methodName.endsWith('Req') || methodName.endsWith('req')) {
      return methodName;
    }
    // 否则添加 Req 后缀
    return '${methodName}Req';
  }

  /// 生成 GET 方法
  static void _generateGetMethod(
    CustomStringBuffer sb,
    String methodName,
    String requestClassName,
    String responseClassName,
    ApiConfig apiConfig,
  ) {
    // 获取实际的方法名,避免重复 Req
    final String actualMethodName = _getActualMethodName(methodName);

    if (apiConfig.useSprintfUrl.value) {
      // 使用 sprintf 格式化 URL (用于路径参数)
      if (apiConfig.requestMode.value == ApiRequestMode.direct) {
        // 直接请求模式
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required String? id,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyHttpUtil().get(');
        sb.writeLine('    sprintf($methodName, [id]),');
        sb.writeLine('  );');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      } else {
        // Form 请求模式 (GET 很少用 form,但仍支持)
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required String? id,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyActionUtil.form().handle(');
        sb.writeLine('    action: () async {');
        sb.writeLine('      return await MyHttpUtil().get(');
        sb.writeLine('        sprintf($methodName, [id]),');
        sb.writeLine('      );');
        sb.writeLine('    },');
        sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
        sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
        sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
        sb.writeLine('  );');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      }
    } else {
      // 普通 GET 请求
      if (apiConfig.requestMode.value == ApiRequestMode.direct) {
        // 直接请求模式
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyHttpUtil().get(');
        sb.writeLine('    $methodName,');
        sb.writeLine('    queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('  );');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      } else {
        // Form 请求模式
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyActionUtil.form().handle(');
        sb.writeLine('    action: () async {');
        sb.writeLine('      return await MyHttpUtil().get(');
        sb.writeLine('        $methodName,');
        sb.writeLine('        queryParameters: req.toJson()..removeWhere((key, value) => value == null),');
        sb.writeLine('      );');
        sb.writeLine('    },');
        sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
        sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
        sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
        sb.writeLine('  );');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      }
    }
  }

  /// 生成 PUT 方法
  static void _generatePutMethod(
    CustomStringBuffer sb,
    String methodName,
    String requestClassName,
    String responseClassName,
    ApiConfig apiConfig,
  ) {
    // 获取实际的方法名,避免重复 Req
    final String actualMethodName = _getActualMethodName(methodName);

    if (apiConfig.requestMode.value == ApiRequestMode.direct) {
      // 直接请求模式
      if (apiConfig.hasResponse.value) {
        // 有响应参数
        sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  var response = await MyHttpUtil().put($methodName,');
        sb.writeLine(
            '      data: req.toJson()..removeWhere((key, value) => value == null));');
        sb.writeLine('  return $responseClassName.fromJson(response);');
        sb.writeLine('}');
      } else {
        // 无响应参数
        sb.writeLine('static Future<dynamic> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  return await MyHttpUtil().put($methodName,');
        sb.writeLine(
            '      data: req.toJson()..removeWhere((key, value) => value == null));');
        sb.writeLine('}');
      }
    } else {
      // Form 请求模式
      sb.writeLine('static Future<bool> $actualMethodName({');
      sb.writeLine('  required $requestClassName req,');
      sb.writeLine('}) async {');
      sb.writeLine('  bool result = await MyActionUtil.form().handle(');
      sb.writeLine('    action: () async {');
      sb.writeLine('      return await MyHttpUtil().put($methodName,');
      sb.writeLine(
          '          data: req.toJson()..removeWhere((key, value) => value == null));');
      sb.writeLine('    },');
      sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
      sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
      sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
      sb.writeLine('  );');
      sb.writeLine('  return result;');
      sb.writeLine('}');
    }
  }

  /// 生成 DELETE 方法
  static void _generateDeleteMethod(
    CustomStringBuffer sb,
    String methodName,
    String requestClassName,
    String responseClassName,
    ApiConfig apiConfig,
  ) {
    // 获取实际的方法名,避免重复 Req
    final String actualMethodName = _getActualMethodName(methodName);

    if (apiConfig.useSprintfUrl.value) {
      // 使用 sprintf 格式化 URL (DELETE 通常用于删除指定 ID 的资源)
      if (apiConfig.requestMode.value == ApiRequestMode.direct) {
        // 直接请求模式
        if (apiConfig.hasResponse.value) {
          sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
          sb.writeLine('  required String? id,');
          sb.writeLine('}) async {');
          sb.writeLine('  var response = await MyHttpUtil().delete(');
          sb.writeLine('    sprintf($methodName, [id]),');
          sb.writeLine('  );');
          sb.writeLine('  return $responseClassName.fromJson(response);');
          sb.writeLine('}');
        } else {
          sb.writeLine('static Future<dynamic> $actualMethodName({');
          sb.writeLine('  required String? id,');
          sb.writeLine('}) async {');
          sb.writeLine('  return await MyHttpUtil().delete(');
          sb.writeLine('    sprintf($methodName, [id]),');
          sb.writeLine('  );');
          sb.writeLine('}');
        }
      } else {
        // Form 请求模式
        sb.writeLine('static Future<bool> $actualMethodName({');
        sb.writeLine('  required String? id,');
        sb.writeLine('}) async {');
        sb.writeLine('  bool result = await MyActionUtil.form().handle(');
        sb.writeLine('    action: () async {');
        sb.writeLine('      return await MyHttpUtil().delete(');
        sb.writeLine('        sprintf($methodName, [id]),');
        sb.writeLine('      );');
        sb.writeLine('    },');
        sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
        sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
        sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
        sb.writeLine('  );');
        sb.writeLine('  return result;');
        sb.writeLine('}');
      }
    } else {
      // 不使用 sprintf (较少见,但仍支持)
      if (apiConfig.requestMode.value == ApiRequestMode.direct) {
        // 直接请求模式
        if (apiConfig.hasResponse.value) {
          sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
          sb.writeLine('  required $requestClassName req,');
          sb.writeLine('}) async {');
          sb.writeLine('  var response = await MyHttpUtil().delete($methodName);');
          sb.writeLine('  return $responseClassName.fromJson(response);');
          sb.writeLine('}');
        } else {
          sb.writeLine('static Future<dynamic> $actualMethodName({');
          sb.writeLine('  required $requestClassName req,');
          sb.writeLine('}) async {');
          sb.writeLine('  return await MyHttpUtil().delete($methodName);');
          sb.writeLine('}');
        }
      } else {
        // Form 请求模式
        sb.writeLine('static Future<bool> $actualMethodName({');
        sb.writeLine('  required $requestClassName req,');
        sb.writeLine('}) async {');
        sb.writeLine('  bool result = await MyActionUtil.form().handle(');
        sb.writeLine('    action: () async {');
        sb.writeLine('      return await MyHttpUtil().delete($methodName);');
        sb.writeLine('    },');
        sb.writeLine("    loadText: '${apiConfig.formLoadText.value}',");
        sb.writeLine("    successText: '${apiConfig.formSuccessText.value}',");
        sb.writeLine("    errorText: '${apiConfig.formErrorText.value}',");
        sb.writeLine('  );');
        sb.writeLine('  return result;');
        sb.writeLine('}');
      }
    }
  }
}

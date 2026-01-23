import 'package:get/get.dart';

/// HTTP 请求方法类型
enum HttpMethod {
  get,
  post,
  put,
  delete,
}

extension HttpMethodExtension on HttpMethod {
  String get name {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.delete:
        return 'DELETE';
    }
  }

  String get methodName {
    switch (this) {
      case HttpMethod.get:
        return 'get';
      case HttpMethod.post:
        return 'post';
      case HttpMethod.put:
        return 'put';
      case HttpMethod.delete:
        return 'delete';
    }
  }
}

/// API 请求模式
enum ApiRequestMode {
  /// 直接请求模式 (用于查询/列表等,直接返回数据)
  direct,

  /// Form 请求模式 (用于增删改操作,带有加载提示和成功/失败提示)
  form,
}

extension ApiRequestModeExtension on ApiRequestMode {
  String get displayName {
    switch (this) {
      case ApiRequestMode.direct:
        return '直接请求';
      case ApiRequestMode.form:
        return 'Form 请求';
    }
  }

  String get description {
    switch (this) {
      case ApiRequestMode.direct:
        return '直接返回结果,适用于查询、列表';
      case ApiRequestMode.form:
        return '带加载提示,适用于增删改';
    }
  }
}

/// Form 请求提示文本预设
enum FormTextPreset {
  /// 提交 (用于新建/提交表单)
  submit,

  /// 保存 (用于保存草稿)
  save,

  /// 删除
  delete,

  /// 自定义
  custom,
}

extension FormTextPresetExtension on FormTextPreset {
  String get displayName {
    switch (this) {
      case FormTextPreset.submit:
        return '提交';
      case FormTextPreset.save:
        return '保存';
      case FormTextPreset.delete:
        return '删除';
      case FormTextPreset.custom:
        return '自定义';
    }
  }

  String get loadText {
    switch (this) {
      case FormTextPreset.submit:
        return '提交中...';
      case FormTextPreset.save:
        return '保存中...';
      case FormTextPreset.delete:
        return '删除中...';
      case FormTextPreset.custom:
        return '';
    }
  }

  String get successText {
    switch (this) {
      case FormTextPreset.submit:
        return '提交成功';
      case FormTextPreset.save:
        return '保存成功';
      case FormTextPreset.delete:
        return '删除成功';
      case FormTextPreset.custom:
        return '';
    }
  }

  String get errorText {
    switch (this) {
      case FormTextPreset.submit:
        return '提交失败';
      case FormTextPreset.save:
        return '保存失败';
      case FormTextPreset.delete:
        return '删除失败';
      case FormTextPreset.custom:
        return '';
    }
  }
}

/// API 生成配置
class ApiConfig {
  /// 是否启用 API 生成模式
  final RxBool apiMode = false.obs;

  /// 是否启用 OpenAPI 批量导入模式
  final RxBool openApiMode = false.obs;

  /// API URL
  final RxString apiUrl = ''.obs;

  /// 请求方法名 (例如: loginReq)
  final RxString methodName = ''.obs;

  /// 方法注释 (例如: 列表)
  final RxString methodComment = ''.obs;

  /// HTTP 方法
  final Rx<HttpMethod> httpMethod = HttpMethod.post.obs;

  /// 请求模式 (直接请求 或 Form请求)
  final Rx<ApiRequestMode> requestMode = ApiRequestMode.direct.obs;

  /// Form 提示文本预设
  final Rx<FormTextPreset> formTextPreset = FormTextPreset.submit.obs;

  /// 请求参数 JSON
  final RxString requestJson = ''.obs;

  /// 响应参数 JSON
  final RxString responseJson = ''.obs;

  /// Base URL (例如: MyEnvConfig.bizUrl + '/api/v1')
  final RxString baseUrl = ''.obs;

  /// 是否使用 sprintf 格式化 URL (用于路径参数)
  final RxBool useSprintfUrl = false.obs;

  /// 是否有响应参数 (如果为 false,则返回 bool)
  final RxBool hasResponse = true.obs;

  /// Form 请求的加载提示文本 (默认: '提交中...')
  final RxString formLoadText = '提交中...'.obs;

  /// Form 请求的成功提示文本 (默认: '提交成功')
  final RxString formSuccessText = '提交成功'.obs;

  /// Form 请求的失败提示文本 (默认: '提交失败')
  final RxString formErrorText = '提交失败'.obs;

  /// 请求参数导出目录 (例如: lib/model/req)
  final RxString requestExportDir = ''.obs;

  /// 响应参数导出目录 (例如: lib/model/resp)
  final RxString responseExportDir = ''.obs;

  /// API 方法导出目录 (例如: lib/api)
  final RxString apiExportDir = ''.obs;

  /// 获取请求参数类名
  String get requestClassName {
    if (methodName.value.isEmpty) {
      return '';
    }
    // 将首字母大写,例如: loginReq -> LoginReq
    final String name = methodName.value;
    return name[0].toUpperCase() + name.substring(1);
  }

  /// 获取响应参数类名
  String get responseClassName {
    if (methodName.value.isEmpty) {
      return '';
    }
    // 将 Req 替换为 Resp,例如: loginReq -> LoginResp
    final String reqClassName = requestClassName;
    if (reqClassName.endsWith('Req')) {
      return reqClassName.substring(0, reqClassName.length - 3) + 'Resp';
    }
    return reqClassName + 'Resp';
  }

  /// 获取请求参数文件名
  String get requestFileName {
    return _toSnakeCase(requestClassName) + '.dart';
  }

  /// 获取响应参数文件名
  String get responseFileName {
    return _toSnakeCase(responseClassName) + '.dart';
  }

  /// 获取 API 文件名
  String get apiFileName {
    if (methodName.value.isEmpty) {
      return '';
    }
    // 移除 Req 后缀,转为 snake_case,例如: loginReq -> login_api.dart
    String name = methodName.value;
    if (name.endsWith('Req') || name.endsWith('req')) {
      name = name.substring(0, name.length - 3);
    }
    return _toSnakeCase(name) + '_api.dart';
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

  void reset() {
    apiUrl.value = '';
    methodName.value = '';
    methodComment.value = '';
    httpMethod.value = HttpMethod.post;
    requestMode.value = ApiRequestMode.direct;
    formTextPreset.value = FormTextPreset.submit;
    requestJson.value = '';
    responseJson.value = '';
    baseUrl.value = '';
    useSprintfUrl.value = false;
    hasResponse.value = true;
    formLoadText.value = '提交中...';
    formSuccessText.value = '提交成功';
    formErrorText.value = '提交失败';
    requestExportDir.value = '';
    responseExportDir.value = '';
    apiExportDir.value = '';
  }
}
